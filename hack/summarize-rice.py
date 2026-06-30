#!/usr/bin/env python3
"""Summarize RICE score coverage on the project board by Workstream Category."""

import json
import subprocess
import sys


def gh_graphql(query: str, variables: dict) -> dict:
    """Run a GraphQL query via gh api graphql."""
    payload = json.dumps({"query": query, "variables": variables})
    result = subprocess.run(
        ["gh", "api", "graphql", "--input", "-"],
        input=payload, capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def fetch_all_items(project_id: str) -> list[dict]:
    """Paginate through all project items."""
    query = """
    query($pid: ID!, $cursor: String) {
      node(id: $pid) {
        ... on ProjectV2 {
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              fieldValues(first: 20) {
                nodes {
                  ... on ProjectV2ItemFieldNumberValue {
                    field { ... on ProjectV2Field { id name } }
                    number
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    field { ... on ProjectV2SingleSelectField { id name } }
                    name
                  }
                }
              }
              content {
                ... on Issue { url state }
              }
            }
          }
        }
      }
    }
    """
    items = []
    cursor = None
    while True:
        variables = {"pid": project_id}
        if cursor:
            variables["cursor"] = cursor
        data = gh_graphql(query, variables)
        page = data["data"]["node"]["items"]
        items.extend(page["nodes"])
        if not page["pageInfo"]["hasNextPage"]:
            break
        cursor = page["pageInfo"]["endCursor"]
    return items


def get_project_id(org: str, project_number: int) -> str:
    result = subprocess.run(
        ["gh", "project", "view", str(project_number), "--owner", org, "--format", "json"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)["id"]


def main():
    org = sys.argv[1] if len(sys.argv) > 1 else "fullsend-ai"
    project_number = int(sys.argv[2]) if len(sys.argv) > 2 else 1

    project_id = get_project_id(org, project_number)
    items = fetch_all_items(project_id)

    # Classify each item.
    rows: dict[str, dict[str, int]] = {}
    cols = [
        "open_with", "open_without",
        "closed_with", "closed_without",
        "total_with", "total_without",
    ]

    for item in items:
        content = item.get("content") or {}
        state = content.get("state", "UNKNOWN")
        if state == "UNKNOWN":
            continue

        field_values = item.get("fieldValues", {}).get("nodes", [])

        category = "(uncategorized)"
        has_rice = False
        for fv in field_values:
            field = fv.get("field") or {}
            if field.get("name") == "Workstream Category":
                category = fv.get("name", "(uncategorized)")
            if field.get("name") == "RICE Score" and fv.get("number") is not None:
                has_rice = True

        if category not in rows:
            rows[category] = {c: 0 for c in cols}

        is_open = state == "OPEN"
        if is_open and has_rice:
            rows[category]["open_with"] += 1
        elif is_open and not has_rice:
            rows[category]["open_without"] += 1
        elif not is_open and has_rice:
            rows[category]["closed_with"] += 1
        else:
            rows[category]["closed_without"] += 1

        if has_rice:
            rows[category]["total_with"] += 1
        else:
            rows[category]["total_without"] += 1

    # Print table.
    headers = [
        "Workstream Category",
        "Open+RICE", "Open-RICE",
        "Closed+RICE", "Closed-RICE",
        "Total+RICE", "Total-RICE",
    ]

    # Compute totals row.
    totals = {c: sum(r[c] for r in rows.values()) for c in cols}

    # Sort rows by total_without descending (most unscored first).
    sorted_cats = sorted(rows.keys(), key=lambda c: rows[c]["total_without"], reverse=True)

    # Calculate column widths.
    cat_width = max(len(headers[0]), max((len(c) for c in sorted_cats), default=0))
    num_width = max(len(h) for h in headers[1:])

    def fmt_row(cat: str, vals: dict[str, int]) -> str:
        parts = [cat.ljust(cat_width)]
        for c in cols:
            parts.append(str(vals[c]).rjust(num_width))
        return "  ".join(parts)

    header_line = "  ".join(
        [headers[0].ljust(cat_width)] + [h.rjust(num_width) for h in headers[1:]]
    )
    sep = "-" * len(header_line)

    print(f"\nRICE Score Summary — {org} project #{project_number}")
    print(f"Total items on board: {len(items)}\n")
    print(header_line)
    print(sep)
    for cat in sorted_cats:
        print(fmt_row(cat, rows[cat]))
    print(sep)
    print(fmt_row("TOTAL", totals))
    print()


if __name__ == "__main__":
    main()
