export const TASK_STATUSES = ["open", "in_progress", "done", "carried", "cancelled"] as const;
export type TaskStatus = (typeof TASK_STATUSES)[number];

export const TASK_PRIORITIES = ["low", "normal", "high", "blocker"] as const;
export type TaskPriority = (typeof TASK_PRIORITIES)[number];

export interface Task {
  id: number;
  title: string;
  description?: string | null;
  assignee?: string | null; // Slack ID (U…)
  status: TaskStatus;
  priority: TaskPriority;
  category?: string | null;
  product?: string | null;
  source?: string | null;
  due_date?: string | null;
  created_at: string;
  updated_at: string;
  metadata?: string | null; // JSON string
  slack_message_ts?: string | null;
  slack_message_url?: string | null;
}

export interface TaskFilters {
  assignee?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  category?: string;
  product?: string;
  overdue?: boolean;
  all?: boolean;
}

export const STATUS_LABEL: Record<TaskStatus, string> = {
  open: "Open",
  in_progress: "In Progress",
  done: "Done",
  carried: "Carried",
  cancelled: "Cancelled",
};

export const STATUS_COLOR: Record<TaskStatus, string> = {
  open: "bg-slate-500/10 text-slate-300 border-slate-500/20",
  in_progress: "bg-blue-500/10 text-blue-300 border-blue-500/20",
  done: "bg-green-500/10 text-green-300 border-green-500/20",
  carried: "bg-amber-500/10 text-amber-300 border-amber-500/20",
  cancelled: "bg-rose-500/10 text-rose-300 border-rose-500/20",
};

export const PRIORITY_LABEL: Record<TaskPriority, string> = {
  low: "Low",
  normal: "Normal",
  high: "High",
  blocker: "Blocker",
};

export const PRIORITY_COLOR: Record<TaskPriority, string> = {
  low: "bg-slate-500/10 text-slate-300 border-slate-500/20",
  normal: "bg-blue-500/10 text-blue-300 border-blue-500/20",
  high: "bg-orange-500/10 text-orange-300 border-orange-500/20",
  blocker: "bg-rose-500/10 text-rose-300 border-rose-500/20",
};

export const PRODUCT_COLOR: Record<string, string> = {
  rapidnative: "bg-cyan-500/10 text-cyan-300 border-cyan-500/20",
  applighter: "bg-purple-500/10 text-purple-300 border-purple-500/20",
  letsdeployit: "bg-pink-500/10 text-pink-300 border-pink-500/20",
};

export const CATEGORY_COLOR: Record<string, string> = {
  marketing: "bg-emerald-500/10 text-emerald-300 border-emerald-500/20",
  sprint: "bg-indigo-500/10 text-indigo-300 border-indigo-500/20",
  bug: "bg-red-500/10 text-red-300 border-red-500/20",
  adhoc: "bg-slate-500/10 text-slate-300 border-slate-500/20",
};
