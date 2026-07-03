"use client";

import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { CalendarDays, Tag, Package } from "lucide-react";
import type { Task } from "@/lib/types";
import { CATEGORY_COLOR, PRIORITY_COLOR, PRIORITY_LABEL, PRODUCT_COLOR } from "@/lib/types";
import { assigneeDisplay, type RosterEntry } from "@/lib/roster";
import { cn } from "@/lib/utils";

interface Props {
  task: Task;
  onClick: (task: Task) => void;
  rosterMap: Map<string, RosterEntry>;
}

export function TaskCard({ task, onClick, rosterMap }: Props) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: task.id,
    data: { type: "task", task },
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  } as const;

  const overdue = task.due_date && new Date(task.due_date) < new Date(new Date().toDateString());
  const person = assigneeDisplay(task.assignee, rosterMap);

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...attributes}
      {...listeners}
      onClick={() => onClick(task)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick(task);
        }
      }}
      role="button"
      tabIndex={0}
      className={cn(
        "group cursor-grab touch-none select-none rounded-md border border-slate-800 bg-slate-900 p-3 shadow-sm outline-none transition hover:border-slate-600 focus-visible:ring-2 focus-visible:ring-slate-500 active:cursor-grabbing",
        isDragging && "z-50 opacity-40"
      )}
    >
      <div className="mb-1.5 flex items-center gap-2 text-[10px] font-mono uppercase tracking-wider text-slate-500">
        T{task.id}
        {overdue && task.status !== "done" && task.status !== "cancelled" && (
          <span className="rounded bg-rose-500/20 px-1 py-0.5 text-rose-300">OVERDUE</span>
        )}
      </div>
      <div className="line-clamp-2 text-sm font-medium text-slate-100">{task.title}</div>
      <div className="mt-3 flex flex-wrap items-center gap-1.5">
        {task.priority !== "normal" && (
          <span className={cn("rounded border px-1.5 py-0.5 text-[10px] font-medium", PRIORITY_COLOR[task.priority])}>
            {PRIORITY_LABEL[task.priority]}
          </span>
        )}
        {task.category && (
          <span
            className={cn(
              "flex items-center gap-1 rounded border px-1.5 py-0.5 text-[10px] font-medium",
              CATEGORY_COLOR[task.category] || "border-slate-700 text-slate-400"
            )}
          >
            <Tag className="h-2.5 w-2.5" />
            {task.category}
          </span>
        )}
        {task.product && (
          <span
            className={cn(
              "flex items-center gap-1 rounded border px-1.5 py-0.5 text-[10px] font-medium",
              PRODUCT_COLOR[task.product] || "border-slate-700 text-slate-400"
            )}
          >
            <Package className="h-2.5 w-2.5" />
            {task.product}
          </span>
        )}
      </div>
      <div className="mt-3 flex items-center justify-between text-[11px] text-slate-500">
        <span className="flex items-center gap-1.5">
          {task.assignee && (
            <>
              <span
                title={person.name}
                className={cn(
                  "inline-flex h-5 w-5 items-center justify-center rounded-full text-[9px] font-semibold uppercase",
                  person.known ? "bg-slate-700 text-slate-100" : "bg-slate-800 text-slate-400"
                )}
              >
                {person.initials}
              </span>
              <span className={cn(person.known ? "text-slate-300" : "text-slate-500")}>{person.handle}</span>
            </>
          )}
        </span>
        {task.due_date && (
          <span
            className={cn(
              "flex items-center gap-1",
              overdue && task.status !== "done" && task.status !== "cancelled" && "text-rose-400"
            )}
          >
            <CalendarDays className="h-3 w-3" />
            {task.due_date}
          </span>
        )}
      </div>
    </div>
  );
}
