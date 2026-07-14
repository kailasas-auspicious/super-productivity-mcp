const BASE_URL = process.env.SP_API_URL ?? "http://127.0.0.1:3876";

export class SpApiError extends Error {
  code: string;
  status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

type Envelope<T> = { ok: true; data: T } | { ok: false; error: { code: string; message: string } };

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers: body !== undefined ? { "Content-Type": "application/json" } : undefined,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch (err) {
    throw new SpApiError(
      "CONNECTION_FAILED",
      `Could not reach Super Productivity's local REST API at ${BASE_URL}. ` +
        `Make sure the desktop app is running and Settings → Misc → "Enable local REST API" is turned on.`,
      0,
    );
  }

  const json = (await res.json().catch(() => null)) as Envelope<T> | null;

  if (!json) {
    throw new SpApiError("INVALID_RESPONSE", `Non-JSON response from ${path} (HTTP ${res.status})`, res.status);
  }
  if (!json.ok) {
    throw new SpApiError(json.error.code, json.error.message, res.status);
  }
  return json.data;
}

export const sp = {
  health: () => request<{ status: string; [k: string]: unknown }>("GET", "/health"),

  listTasks: (params: {
    query?: string;
    projectId?: string;
    tagId?: string;
    includeDone?: boolean;
    source?: "active" | "archived" | "all";
  }) => {
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined) qs.set(k, String(v));
    }
    const suffix = qs.toString() ? `?${qs.toString()}` : "";
    return request<unknown[]>("GET", `/tasks${suffix}`);
  },

  getTask: (id: string) => request<unknown>("GET", `/tasks/${encodeURIComponent(id)}`),

  createTask: (body: Record<string, unknown>) => request<unknown>("POST", "/tasks", body),

  updateTask: (id: string, body: Record<string, unknown>) =>
    request<unknown>("PATCH", `/tasks/${encodeURIComponent(id)}`, body),

  deleteTask: (id: string) => request<unknown>("DELETE", `/tasks/${encodeURIComponent(id)}`),

  startTask: (id: string) => request<unknown>("POST", `/tasks/${encodeURIComponent(id)}/start`),

  archiveTask: (id: string) => request<unknown>("POST", `/tasks/${encodeURIComponent(id)}/archive`),

  restoreTask: (id: string) => request<unknown>("POST", `/tasks/${encodeURIComponent(id)}/restore`),

  getStatus: () => request<unknown>("GET", "/status"),

  getCurrentTask: () => request<unknown>("GET", "/task-control/current"),

  setCurrentTask: (taskId: string | null) =>
    request<unknown>("POST", "/task-control/current", { taskId }),

  stopCurrentTask: () => request<unknown>("POST", "/task-control/stop"),

  listProjects: (title?: string) =>
    request<unknown[]>("GET", `/projects${title ? `?title=${encodeURIComponent(title)}` : ""}`),

  listTags: (title?: string) =>
    request<unknown[]>("GET", `/tags${title ? `?title=${encodeURIComponent(title)}` : ""}`),
};
