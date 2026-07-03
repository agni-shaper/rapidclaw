"use client";

import { Search, X } from "lucide-react";
import type { TaskPriority } from "@/lib/types";
import { PRIORITY_LABEL, TASK_PRIORITIES } from "@/lib/types";
import { cn } from "@/lib/utils";

export interface Filters {
  q: string;
  assignee: string;
  priority: string;
  category: string;
  product: string;
  overdueOnly: boolean;
}

export const EMPTY_FILTERS: Filters = {
  q: "",
  assignee: "",
  priority: "",
  category: "",
  product: "",
  overdueOnly: false,
};

interface Props {
  filters: Filters;
  onChange: (f: Filters) => void;
  assigneeOptions: { id: string; label: string }[];
  categoryOptions: string[];
  productOptions: string[];
  totalCount: number;
  filteredCount: number;
}

export function FiltersBar({
  filters,
  onChange,
  assigneeOptions,
  categoryOptions,
  productOptions,
  totalCount,
  filteredCount,
}: Props) {
  const set = <K extends keyof Filters>(k: K, v: Filters[K]) => onChange({ ...filters, [k]: v });
  const hasActive =
    filters.q ||
    filters.assignee ||
    filters.priority ||
    filters.category ||
    filters.product ||
    filters.overdueOnly;

  return (
    <div className="flex flex-wrap items-center gap-2 border-b border-slate-800 bg-slate-950 px-4 py-3">
      <div className="relative">
        <Search className="pointer-events-none absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-500" />
        <input
          type="text"
          placeholder="Search title…"
          value={filters.q}
          onChange={(e) => set("q", e.target.value)}
          className="w-56 rounded border border-slate-800 bg-slate-900 py-1.5 pl-7 pr-2 text-sm text-slate-100 placeholder:text-slate-600 focus:border-slate-600 focus:outline-none"
        />
      </div>

      <FilterSelect
        label="Assignee"
        value={filters.assignee}
        onChange={(v) => set("assignee", v)}
        options={[{ value: "", label: "Any assignee" }, ...assigneeOptions.map((a) => ({ value: a.id, label: a.label }))]}
      />

      <FilterSelect
        label="Priority"
        value={filters.priority}
        onChange={(v) => set("priority", v)}
        options={[
          { value: "", label: "Any priority" },
          ...TASK_PRIORITIES.map((p) => ({ value: p, label: PRIORITY_LABEL[p as TaskPriority] })),
        ]}
      />

      <FilterSelect
        label="Category"
        value={filters.category}
        onChange={(v) => set("category", v)}
        options={[{ value: "", label: "Any category" }, ...categoryOptions.map((c) => ({ value: c, label: c }))]}
      />

      <FilterSelect
        label="Product"
        value={filters.product}
        onChange={(v) => set("product", v)}
        options={[{ value: "", label: "Any product" }, ...productOptions.map((p) => ({ value: p, label: p }))]}
      />

      <label className={cn(
        "flex cursor-pointer items-center gap-1.5 rounded border px-2 py-1.5 text-xs transition",
        filters.overdueOnly ? "border-rose-500/40 bg-rose-500/10 text-rose-300" : "border-slate-800 text-slate-400 hover:border-slate-700"
      )}>
        <input
          type="checkbox"
          className="sr-only"
          checked={filters.overdueOnly}
          onChange={(e) => set("overdueOnly", e.target.checked)}
        />
        Overdue only
      </label>

      {hasActive && (
        <button
          onClick={() => onChange(EMPTY_FILTERS)}
          className="ml-1 flex items-center gap-1 rounded border border-slate-800 px-2 py-1.5 text-xs text-slate-400 transition hover:border-slate-700 hover:text-slate-200"
        >
          <X className="h-3 w-3" /> Reset
        </button>
      )}

      <div className="ml-auto text-xs text-slate-500">
        Showing <span className="font-medium text-slate-300">{filteredCount}</span> of{" "}
        <span className="font-medium text-slate-300">{totalCount}</span>
      </div>
    </div>
  );
}

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <select
      aria-label={label}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className={cn(
        "cursor-pointer rounded border px-2 py-1.5 text-xs transition focus:border-slate-600 focus:outline-none",
        value ? "border-slate-600 bg-slate-800 text-slate-100" : "border-slate-800 bg-slate-900 text-slate-400"
      )}
    >
      {options.map((o) => (
        <option key={o.value || "any"} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}
