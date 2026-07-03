"use client";

import { useDroppable } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import type { Task, TaskStatus } from "@/lib/types";
import { STATUS_COLOR, STATUS_LABEL } from "@/lib/types";
import { cn } from "@/lib/utils";
import { TaskCard } from "./task-card";
import type { RosterEntry } from "@/lib/roster";

interface Props {
  status: TaskStatus;
  tasks: Task[];
  onCardClick: (task: Task) => void;
  rosterMap: Map<string, RosterEntry>;
}

export function KanbanColumn({ status, tasks, onCardClick, rosterMap }: Props) {
  const { setNodeRef, isOver } = useDroppable({
    id: `column-${status}`,
    data: { type: "column", status },
  });

  return (
    <div className="flex h-full min-h-0 w-72 flex-shrink-0 flex-col">
      <div className="mb-3 flex items-center justify-between px-1">
        <div className="flex items-center gap-2">
          <span className={cn("rounded border px-2 py-0.5 text-xs font-semibold uppercase tracking-wider", STATUS_COLOR[status])}>
            {STATUS_LABEL[status]}
          </span>
          <span className="text-xs text-slate-500">{tasks.length}</span>
        </div>
      </div>
      <div
        ref={setNodeRef}
        className={cn(
          "flex flex-1 flex-col gap-2 overflow-y-auto rounded-lg border border-dashed border-slate-800/60 bg-slate-900/30 p-2 transition",
          isOver && "border-slate-600 bg-slate-900/60"
        )}
      >
        <SortableContext items={tasks.map((t) => t.id)} strategy={verticalListSortingStrategy}>
          {tasks.length === 0 ? (
            <div className="flex flex-1 items-center justify-center text-xs text-slate-600">
              Drop tasks here
            </div>
          ) : (
            tasks.map((task) => (
              <TaskCard key={task.id} task={task} onClick={onCardClick} rosterMap={rosterMap} />
            ))
          )}
        </SortableContext>
      </div>
    </div>
  );
}
