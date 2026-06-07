#!/usr/bin/env python3
"""Plot simulation CSV attributes as colored line graphs.

By default this writes an SVG using only the Python standard library:

    python3 misc/visualize_csv.py

To plot a specific CSV:

    python3 misc/visualize_csv.py data/run_2026-06-07T19-54-22.csv

If matplotlib is installed, PNG output and interactive display are also supported:

    python3 misc/visualize_csv.py --output misc/simulation_graph.png --show
"""

from __future__ import annotations

import argparse
import csv
from html import escape
from pathlib import Path
import sys


COLORS = [
    "#2563eb",
    "#dc2626",
    "#16a34a",
    "#9333ea",
    "#ea580c",
    "#0891b2",
    "#be123c",
    "#4d7c0f",
    "#7c3aed",
    "#ca8a04",
    "#0f766e",
    "#db2777",
]


def default_csv_path(project_root: Path) -> Path:
    data_dir = project_root / "data"
    candidates = sorted(data_dir.glob("run_*.csv"), key=lambda path: path.stat().st_mtime)

    if candidates:
        return candidates[-1]

    return data_dir / "simulation_data.csv"


def read_numeric_columns(csv_path: Path) -> tuple[str, list[float], dict[str, list[float]]]:
    with csv_path.open(newline="") as csv_file:
        reader = csv.DictReader(csv_file)

        if reader.fieldnames is None:
            raise ValueError(f"{csv_path} does not contain a header row")

        fieldnames = reader.fieldnames
        x_field = "epoch" if "epoch" in fieldnames else fieldnames[0]
        columns = {field: [] for field in fieldnames if field != x_field}
        x_values: list[float] = []

        for row_number, row in enumerate(reader, start=2):
            try:
                x_values.append(float(row[x_field]))
            except (TypeError, ValueError) as error:
                raise ValueError(
                    f"Row {row_number}: x-axis column {x_field!r} is not numeric"
                ) from error

            for field in list(columns):
                try:
                    columns[field].append(float(row[field]))
                except (TypeError, ValueError):
                    columns.pop(field)

    return x_field, x_values, columns


def scale(value: float, min_value: float, max_value: float, start: float, end: float) -> float:
    if max_value == min_value:
        return (start + end) / 2

    ratio = (value - min_value) / (max_value - min_value)
    return start + ratio * (end - start)


def polyline_points(
    x_values: list[float],
    y_values: list[float],
    min_x: float,
    max_x: float,
    min_y: float,
    max_y: float,
    plot_left: float,
    plot_top: float,
    plot_width: float,
    plot_height: float,
) -> str:
    points = []

    for x_value, y_value in zip(x_values, y_values):
        x = scale(x_value, min_x, max_x, plot_left, plot_left + plot_width)
        y = scale(y_value, min_y, max_y, plot_top + plot_height, plot_top)
        points.append(f"{x:.2f},{y:.2f}")

    return " ".join(points)


def write_svg(
    csv_path: Path,
    output_path: Path,
    x_field: str,
    x_values: list[float],
    columns: dict[str, list[float]],
) -> None:
    width = 1280
    height = 760
    plot_left = 80
    plot_top = 70
    plot_width = 900
    plot_height = 600
    legend_left = 1010
    legend_top = 92

    all_y_values = [value for values in columns.values() for value in values]
    min_x = min(x_values)
    max_x = max(x_values)
    min_y = min(all_y_values)
    max_y = max(all_y_values)

    if min_y == max_y:
        min_y -= 1
        max_y += 1

    x_ticks = [min_x, (min_x + max_x) / 2, max_x]
    y_ticks = [min_y, (min_y + max_y) / 2, max_y]

    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 0 {width} {height}" width="{width}" height="{height}">',
        "<style>",
        "text { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; fill: #111827; }",
        ".grid { stroke: #d1d5db; stroke-width: 1; }",
        ".axis { stroke: #111827; stroke-width: 1.5; }",
        "</style>",
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        f'<text x="{plot_left}" y="34" font-size="24" font-weight="700">'
        f"Simulation Attributes: {escape(csv_path.name)}</text>",
    ]

    for tick in x_ticks:
        x = scale(tick, min_x, max_x, plot_left, plot_left + plot_width)
        lines.append(
            f'<line class="grid" x1="{x:.2f}" y1="{plot_top}" '
            f'x2="{x:.2f}" y2="{plot_top + plot_height}"/>'
        )
        lines.append(
            f'<text x="{x:.2f}" y="{plot_top + plot_height + 28}" '
            f'font-size="13" text-anchor="middle">{tick:.0f}</text>'
        )

    for tick in y_ticks:
        y = scale(tick, min_y, max_y, plot_top + plot_height, plot_top)
        lines.append(
            f'<line class="grid" x1="{plot_left}" y1="{y:.2f}" '
            f'x2="{plot_left + plot_width}" y2="{y:.2f}"/>'
        )
        lines.append(
            f'<text x="{plot_left - 12}" y="{y + 4:.2f}" '
            f'font-size="13" text-anchor="end">{tick:.2f}</text>'
        )

    lines.extend(
        [
            f'<line class="axis" x1="{plot_left}" y1="{plot_top + plot_height}" '
            f'x2="{plot_left + plot_width}" y2="{plot_top + plot_height}"/>',
            f'<line class="axis" x1="{plot_left}" y1="{plot_top}" '
            f'x2="{plot_left}" y2="{plot_top + plot_height}"/>',
            f'<text x="{plot_left + plot_width / 2}" y="{height - 24}" '
            f'font-size="15" text-anchor="middle">{escape(x_field)}</text>',
            '<text transform="translate(20 390) rotate(-90)" '
            'font-size="15" text-anchor="middle">value</text>',
        ]
    )

    for index, (name, values) in enumerate(columns.items()):
        color = COLORS[index % len(COLORS)]
        points = polyline_points(
            x_values[: len(values)],
            values,
            min_x,
            max_x,
            min_y,
            max_y,
            plot_left,
            plot_top,
            plot_width,
            plot_height,
        )
        legend_y = legend_top + index * 28

        lines.append(
            f'<polyline points="{points}" fill="none" stroke="{color}" '
            'stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>'
        )
        lines.append(
            f'<line x1="{legend_left}" y1="{legend_y}" '
            f'x2="{legend_left + 28}" y2="{legend_y}" stroke="{color}" stroke-width="3"/>'
        )
        lines.append(
            f'<text x="{legend_left + 38}" y="{legend_y + 5}" font-size="14">'
            f"{escape(name)}</text>"
        )

    lines.append("</svg>")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Saved graph to {output_path}")


def plot_with_matplotlib(
    csv_path: Path,
    output_path: Path | None,
    x_field: str,
    x_values: list[float],
    columns: dict[str, list[float]],
    show_plot: bool,
) -> bool:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return False

    plt.figure(figsize=(13, 7))

    for name, values in columns.items():
        plt.plot(x_values[: len(values)], values, linewidth=1.8, label=name)

    plt.title(f"Simulation Attributes: {csv_path.name}")
    plt.xlabel(x_field)
    plt.ylabel("value")
    plt.grid(True, alpha=0.3)
    plt.legend(loc="center left", bbox_to_anchor=(1.02, 0.5))
    plt.tight_layout()

    if output_path is not None:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(output_path, dpi=160)
        print(f"Saved graph to {output_path}")

    if show_plot:
        plt.show()

    return True


def parse_args() -> argparse.Namespace:
    project_root = Path(__file__).resolve().parents[1]
    default_csv = default_csv_path(project_root)

    parser = argparse.ArgumentParser(
        description="Plot each numeric simulation CSV attribute as a separate line."
    )
    parser.add_argument(
        "csv_path",
        nargs="?",
        type=Path,
        default=default_csv,
        help=f"CSV to plot. Defaults to newest run CSV: {default_csv}",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output image path. Use .svg for no dependencies, or .png with matplotlib.",
    )
    parser.add_argument(
        "--show",
        action="store_true",
        help="Open an interactive matplotlib window if matplotlib is installed.",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    csv_path = args.csv_path.resolve()

    if not csv_path.exists():
        print(f"CSV not found: {csv_path}", file=sys.stderr)
        return 1

    x_field, x_values, columns = read_numeric_columns(csv_path)

    if not x_values:
        print(f"No data rows found in {csv_path}", file=sys.stderr)
        return 1

    if not columns:
        print(f"No numeric attribute columns found in {csv_path}", file=sys.stderr)
        return 1

    output_path = args.output

    if output_path is None and not args.show:
        output_path = Path(__file__).resolve().with_name("simulation_graph.svg")

    wants_svg = output_path is not None and output_path.suffix.lower() == ".svg"

    if not wants_svg:
        plotted = plot_with_matplotlib(
            csv_path, output_path, x_field, x_values, columns, show_plot=args.show
        )
        if plotted:
            return 0

        if output_path is not None and output_path.suffix.lower() != ".svg":
            print("matplotlib is not installed; writing SVG instead.")

    svg_path = (
        output_path
        if output_path is not None and output_path.suffix.lower() == ".svg"
        else Path(__file__).resolve().with_name("simulation_graph.svg")
    )
    write_svg(csv_path, svg_path, x_field, x_values, columns)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
