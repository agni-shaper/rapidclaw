"use client";

import { useMemo, useState } from "react";
import {
  DndContext,
  DragOverlay,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from "@dnd-kit/core";
import type { Task, TaskStatus } from "@/lib/types";
import { TASK_STATUSES } from "@/lib/types";
import { EMPTY_FILTERS, Filters, FiltersBar } from "./filters-bar";
import { KanbanColumn } from "./kanban-column";
import { TaskCard } from "./task-card";
import { TaskFlyout } from "./task-flyout";
import { RefreshCw, Loader2 } from "lucide-react";

interface Props {
  initialTasks: Task[];
}

export function KanbanBoard({ initialTasks }: Props) {
  const [tasks, setTasks] = useState<Task[]>(initialTasks);
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [flyoutOpen, setFlyoutOpen] = useState(false);
  const [activeTask, setActiveTask] = useState<Task | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));

  const filtered = useMemo(() => {
    const today = new Date(new Date().toDateString());
    const q = filters.q.toLowerCase().trim();
    return tasks.filter((t) => {
      if (q && !t.title.toLowerCase().includes(q)) return false;
      if (filters.assignee && t.assignee !== filters.assignee) return false;
      if (filters.priority && t.priority !== filters.priority) return false;
      if (filters.category && t.category !== filters.category) return false;
      if (filters.product && t.product !== filters.product) return false;
      if (filters.overdueOnly) {
        if (!t.due_date) return false;
        if (new Date(t.due_date) >= today) return false;
        if (t.status === "done" || t.status === "cancelled") return false;
      }
      return true;
    });
  }, [tasks, filters]);

  const byStatus = useMemo(() => {
    const m: Record<TaskStatus, Task[]> = { open: [], in_progress: [], done: [], carried: [], cancelled: [] };
    for (const t of filtered) m[t.status].push(t);
    return m;
  }, [filtered]);

  const assigneeOptions = useMemo(() => {
    const map = new Map<string, number>();
    for (const t of tasks) if (t.assignee) map.set(t.assignee, (map.get(t.assignee) || 0) + 1);
    return Array.from(map.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([id, n]) => ({ id, label: `${id} (${n})` }));
  }, [tasks]);

  const categoryOptions = useMemo(() => {
    return Array.from(new Set(tasks.map((t) => t.category).filter((c): c is string => !!c))).sort();
  }, [tasks]);

  const productOptions = useMemo(() => {
    return Array.from(new Set(tasks.map((t) => t.product).filter((p): p is string => !!p))).sort();
  }, [tasks]);

  function openTask(t: Task) {
    setSelectedTask(t);
    setFlyoutOpen(true);
  }

  function onTaskUpdated(updated: Task) {
    setTasks((prev) => prev.map((t) => (t.id === updated.id ? updated : t)));
    setSelectedTask(updated);
  }

  async function refresh() {
    setRefreshing(true);
    try {
      const res = await fetch("/api/tasks", { cache: "no-store" });
      if (res.ok) setTasks(await res.json());
    } finally {
      setRefreshing(false);
    }
  }

  function handleDragStart(event: DragStartEvent) {
    const t = tasks.find((x) => x.id === Number(event.active.id));
    if (t) setActiveTask(t);
  }

  async function handleDragEnd(event: DragEndEvent) {
    setActiveTask(null);
    const { active, over } = event;
    if (!over) return;

    const activeId = Number(active.id);
    const task = tasks.find((t) => t.id === activeId);
    if (!task) return;

    const overType = over.data.current?.type;
    let newStatus: TaskStatus | null = null;

    if (overType === "column") {
      newStatus = over.data.current!.status as TaskStatus;
    } else if (overType === "task") {
      const overTask = over.data.current!.task as Task;
      newStatus = overTask.status;
    }

    if (!newStatus || newStatus === task.status) return;

    // Optimistic UI
    const optimistic = { ...task, status: newStatus };
    setTasks((prev) => prev.map((t) => (t.id === activeId ? optimistic : t)));

    try {
      const res = await fetch(`/api/tasks/${activeId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: newStatus }),
      });
      if (!res.ok) throw new Error("update failed");
      const updated = (await res.json()) as Task;
      setTasks((prev) => prev.map((t) => (t.id === activeId ? updated : t)));
    } catch {
      // Revert on failure
      setTasks((prev) => prev.map((t) => (t.id === activeId ? task : t)));
    }
  }

  return (
    <div className="flex h-screen flex-col bg-slate-950 text-slate-100">
      <div className="flex items-center justify-between border-b border-slate-800 bg-slate-950 px-4 py-3">
        <div className="flex items-center gap-3">
          <h1 className="text-lg font-semibold">Tasks</h1>
          <span className="text-xs text-slate-500">Kanban · sqlite-backed · every drag writes via tasks.sh</span>
        </div>
        <button
          onClick={refresh}
          disabled={refreshing}
          className="flex items-center gap-1.5 rounded border border-slate-800 px-2 py-1.5 text-xs text-slate-400 transition hover:border-slate-700 hover:text-slate-200 disabled:opacity-50"
        >
          {refreshing ? <Loader2 className="h-3 w-3 animate-spin" /> : <RefreshCw className="h-3 w-3" />}
          Refresh
        </button>
      </div>

      <FiltersBar
        filters={filters}
        onChange={setFilters}
        assigneeOptions={assigneeOptions}
        categoryOptions={categoryOptions}
        productOptions={productOptions}
        totalCount={tasks.length}
        filteredCount={filtered.length}
      />

      <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
        <div className="flex flex-1 gap-4 overflow-x-auto p-4">
          {TASK_STATUSES.map((s) => (
            <KanbanColumn key={s} status={s} tasks={byStatus[s]} onCardClick={openTask} />
          ))}
        </div>
        <DragOverlay>{activeTask ? <TaskCard task={activeTask} onClick={() => {}} /> : null}</DragOverlay>
      </DndContext>

      <TaskFlyout task={selectedTask} open={flyoutOpen} onOpenChange={setFlyoutOpen} onSaved={onTaskUpdated} />
    </div>
  );
}
