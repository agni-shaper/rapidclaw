"use client";

import { useState } from "react";
import { ExternalLink, Loader2 } from "lucide-react";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import type { Task, TaskPriority, TaskStatus } from "@/lib/types";
import {
  CATEGORY_COLOR,
  PRIORITY_COLOR,
  PRIORITY_LABEL,
  PRODUCT_COLOR,
  STATUS_COLOR,
  STATUS_LABEL,
  TASK_PRIORITIES,
  TASK_STATUSES,
} from "@/lib/types";
import { cn } from "@/lib/utils";

interface Props {
  task: Task | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSaved: (task: Task) => void;
}

export function TaskFlyout({ task, open, onOpenChange, onSaved }: Props) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!task) {
    return (
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent />
      </Sheet>
    );
  }

  async function patch(fields: Partial<Task>) {
    if (!task) return;
    setSaving(true);
    setError(null);
    try {
      const res = await fetch(`/api/tasks/${task.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(fields),
      });
      if (!res.ok) throw new Error((await res.json()).error || "Save failed");
      const updated = (await res.json()) as Task;
      onSaved(updated);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const parsedMetadata = (() => {
    try {
      return task.metadata ? JSON.parse(task.metadata) : null;
    } catch {
      return null;
    }
  })();

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="overflow-y-auto">
        <SheetHeader>
          <div className="flex items-center gap-2 text-xs font-mono uppercase tracking-wider text-slate-500">
            <span>T{task.id}</span>
            <span
              className={cn(
                "rounded border px-2 py-0.5 text-[10px] font-semibold",
                STATUS_COLOR[task.status]
              )}
            >
              {STATUS_LABEL[task.status]}
            </span>
          </div>
          <SheetTitle className="pr-4 leading-snug">{task.title}</SheetTitle>
          {task.description && <SheetDescription>{task.description}</SheetDescription>}
        </SheetHeader>

        {error && (
          <div className="rounded border border-rose-500/40 bg-rose-500/10 px-3 py-2 text-xs text-rose-300">
            {error}
          </div>
        )}

        <div className="grid grid-cols-2 gap-x-4 gap-y-4 text-sm">
          <Field label="Assignee">
            <span className="font-mono text-slate-300">{task.assignee || "—"}</span>
          </Field>
          <Field label="Due date">
            <span className="font-mono text-slate-300">{task.due_date || "—"}</span>
          </Field>
          <Field label="Priority">
            <select
              value={task.priority}
              onChange={(e) => patch({ priority: e.target.value as TaskPriority })}
              disabled={saving}
              className={cn(
                "cursor-pointer rounded border px-2 py-1 text-xs font-medium",
                PRIORITY_COLOR[task.priority]
              )}
            >
              {TASK_PRIORITIES.map((p) => (
                <option key={p} value={p}>
                  {PRIORITY_LABEL[p]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Status">
            <select
              value={task.status}
              onChange={(e) => patch({ status: e.target.value as TaskStatus })}
              disabled={saving}
              className={cn(
                "cursor-pointer rounded border px-2 py-1 text-xs font-medium",
                STATUS_COLOR[task.status]
              )}
            >
              {TASK_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {STATUS_LABEL[s]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Category">
            <span
              className={cn(
                "inline-block rounded border px-1.5 py-0.5 text-[10px] font-medium",
                task.category
                  ? CATEGORY_COLOR[task.category] || "border-slate-700 text-slate-400"
                  : "border-slate-800 text-slate-600"
              )}
            >
              {task.category || "—"}
            </span>
          </Field>
          <Field label="Product">
            <span
              className={cn(
                "inline-block rounded border px-1.5 py-0.5 text-[10px] font-medium",
                task.product
                  ? PRODUCT_COLOR[task.product] || "border-slate-700 text-slate-400"
                  : "border-slate-800 text-slate-600"
              )}
            >
              {task.product || "—"}
            </span>
          </Field>
        </div>

        <Field label="Source">
          <span className="break-all font-mono text-xs text-slate-400">{task.source || "—"}</span>
        </Field>

        <div className="grid grid-cols-2 gap-4 text-xs text-slate-500">
          <div>
            <div className="mb-1 text-[10px] uppercase tracking-wider text-slate-600">Created</div>
            <div className="font-mono">{task.created_at}</div>
          </div>
          <div>
            <div className="mb-1 text-[10px] uppercase tracking-wider text-slate-600">Updated</div>
            <div className="font-mono">{task.updated_at}</div>
          </div>
        </div>

        {task.slack_message_url && (
          <a
            href={task.slack_message_url}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 rounded border border-slate-800 bg-slate-900 px-3 py-2 text-sm font-medium text-slate-200 transition hover:border-slate-700 hover:bg-slate-800"
          >
            <ExternalLink className="h-4 w-4" />
            Open Slack thread
          </a>
        )}

        {parsedMetadata && (
          <div>
            <div className="mb-1 text-[10px] uppercase tracking-wider text-slate-600">Metadata</div>
            <pre className="max-h-64 overflow-auto rounded border border-slate-800 bg-slate-900 p-3 text-[11px] leading-relaxed text-slate-400">
              {JSON.stringify(parsedMetadata, null, 2)}
            </pre>
          </div>
        )}

        <div className="mt-auto flex items-center justify-between border-t border-slate-800 pt-4">
          <div className="text-xs text-slate-500">
            {saving && (
              <span className="inline-flex items-center gap-1">
                <Loader2 className="h-3 w-3 animate-spin" /> Saving…
              </span>
            )}
          </div>
          <div className="flex gap-2">
            {task.status !== "done" && (
              <button
                onClick={() => patch({ status: "done" })}
                disabled={saving}
                className="rounded bg-green-500/20 px-3 py-1.5 text-sm font-medium text-green-300 transition hover:bg-green-500/30 disabled:opacity-50"
              >
                Mark done
              </button>
            )}
            {task.status !== "cancelled" && (
              <button
                onClick={() => patch({ status: "cancelled" })}
                disabled={saving}
                className="rounded bg-rose-500/20 px-3 py-1.5 text-sm font-medium text-rose-300 transition hover:bg-rose-500/30 disabled:opacity-50"
              >
                Cancel
              </button>
            )}
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="mb-1 text-[10px] uppercase tracking-wider text-slate-600">{label}</div>
      <div>{children}</div>
    </div>
  );
}
