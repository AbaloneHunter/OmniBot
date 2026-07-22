import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { conversationKey, modeLabel, relativeDate } from "../format";
import type { ConnectionStatus, Conversation, ConversationMode } from "../types";
import { Icon, type IconName } from "./Icon";

interface ConversationSidebarProps {
  conversations: Conversation[];
  selected: Conversation | null;
  archivedOnly: boolean;
  connectionStatus: ConnectionStatus;
  onCreate: (mode: ConversationMode) => void;
  onSelect: (conversation: Conversation) => void;
  onToggleArchived: () => void;
}

const STATUS_LABELS: Record<ConnectionStatus, string> = {
  online: "实时连接正常",
  offline: "连接中断，正在重试",
  connecting: "正在连接实时事件",
};

const SECTION_ORDER = ["codex", "agent", "chat"] as const;

type ConversationSection = typeof SECTION_ORDER[number];

const SECTION_LABELS: Record<ConversationSection, string> = {
  codex: "Codex",
  agent: "Agent",
  chat: "纯聊天",
};

const CREATE_OPTIONS: ReadonlyArray<{
  mode: ConversationMode;
  label: string;
  icon: IconName;
}> = [
  { mode: "normal", label: "Agent 模式", icon: "agent" },
  { mode: "codex", label: "Codex 模式", icon: "codex" },
  { mode: "chat_only", label: "纯聊天模式", icon: "chat" },
];

function conversationSection(conversation: Conversation): ConversationSection {
  if (conversation.mode === "codex") return "codex";
  if (conversation.mode === "chat_only") return "chat";
  return "agent";
}

export function ConversationSidebar({
  conversations,
  selected,
  archivedOnly,
  connectionStatus,
  onCreate,
  onSelect,
  onToggleArchived,
}: ConversationSidebarProps) {
  const [search, setSearch] = useState("");
  const [collapsedSections, setCollapsedSections] = useState<Set<string>>(new Set());
  const [createMenuOpen, setCreateMenuOpen] = useState(false);
  const createMenuAnchorRef = useRef<HTMLDivElement>(null);
  const createButtonRef = useRef<HTMLButtonElement>(null);
  const createMenuRef = useRef<HTMLDivElement>(null);
  const query = search.trim().toLowerCase();

  useEffect(() => {
    if (!createMenuOpen) return undefined;
    const focusFrame = window.requestAnimationFrame(() => {
      createMenuRef.current?.querySelector<HTMLButtonElement>("[role='menuitem']")?.focus();
    });
    const handlePointerDown = (event: PointerEvent) => {
      if (!createMenuAnchorRef.current?.contains(event.target as Node)) {
        setCreateMenuOpen(false);
      }
    };
    const handleKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      setCreateMenuOpen(false);
      createButtonRef.current?.focus();
    };
    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [createMenuOpen]);

  function handleCreateMenuKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;
    const items = [...(createMenuRef.current?.querySelectorAll<HTMLButtonElement>("[role='menuitem']") ?? [])];
    if (!items.length) return;
    event.preventDefault();
    const currentIndex = items.indexOf(document.activeElement as HTMLButtonElement);
    const nextIndex = event.key === "Home"
      ? 0
      : event.key === "End"
        ? items.length - 1
        : event.key === "ArrowDown"
          ? currentIndex < 0 ? 0 : (currentIndex + 1) % items.length
          : currentIndex < 0 ? items.length - 1 : (currentIndex - 1 + items.length) % items.length;
    items[nextIndex].focus();
  }

  function createConversation(mode: ConversationMode) {
    setCreateMenuOpen(false);
    onCreate(mode);
  }

  function toggleSection(id: string) {
    setCollapsedSections((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const sections = useMemo(() => {
    const visible = query
      ? conversations.filter((conversation) => (
        [conversation.title, conversation.summary, conversation.lastMessage]
          .some((value) => String(value ?? "").toLowerCase().includes(query))
      ))
      : conversations;
    return SECTION_ORDER
      .map((id) => ({
        id,
        items: visible.filter((conversation) => conversationSection(conversation) === id),
      }))
      .filter((section) => section.items.length > 0);
  }, [conversations, query]);
  const resultCount = sections.reduce((total, section) => total + section.items.length, 0);

  return (
    <aside className="conversation-pane">
      <div className="conversation-toolbar">
        <div className="search-field">
          <Icon name="search" size={17} />
          <input
            type="search"
            aria-label="搜索对话"
            placeholder="搜索对话"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
          {search && (
            <button className="search-clear" type="button" aria-label="清除搜索" onClick={() => setSearch("")}>
              <Icon name="x" size={14} />
            </button>
          )}
        </div>
        <button
          className={`sidebar-round-button${archivedOnly ? " active" : ""}`}
          type="button"
          aria-label={archivedOnly ? "返回当前对话" : "查看归档对话"}
          title={archivedOnly ? "返回当前对话" : "查看归档对话"}
          onClick={onToggleArchived}
        >
          {archivedOnly ? <Icon name="chevron-left" size={18} /> : <Icon name="archive" size={17} />}
        </button>
        <div
          className="new-conversation-anchor"
          ref={createMenuAnchorRef}
          onBlur={(event) => {
            if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
              setCreateMenuOpen(false);
            }
          }}
        >
          <button
            className="sidebar-round-button primary"
            type="button"
            aria-label="新建对话"
            aria-haspopup="menu"
            aria-expanded={createMenuOpen}
            aria-controls={createMenuOpen ? "new-conversation-menu" : undefined}
            title="新建对话"
            ref={createButtonRef}
            onClick={() => setCreateMenuOpen((open) => !open)}
          >
            <Icon name="plus" size={18} />
          </button>
          {createMenuOpen && (
            <div
              className="new-conversation-menu"
              id="new-conversation-menu"
              role="menu"
              aria-label="选择新对话模式"
              ref={createMenuRef}
              onKeyDown={handleCreateMenuKeyDown}
            >
              {CREATE_OPTIONS.map((option) => (
                <button
                  className="new-conversation-menu-item"
                  type="button"
                  role="menuitem"
                  key={option.mode}
                  onClick={() => createConversation(option.mode)}
                >
                  <span className="new-conversation-menu-icon">
                    <Icon name={option.icon} size={17} />
                  </span>
                  <span>{option.label}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="conversation-list" aria-live="polite">
        {query && resultCount > 0 && (
          <div className="search-summary">
            <span>搜索结果</span>
            <span>{resultCount}</span>
          </div>
        )}
        {!resultCount && (
          <div className="list-empty">
            <Icon name={query ? "search" : "agent"} size={24} />
            <strong>{query ? "没有找到相关对话" : archivedOnly ? "没有归档对话" : "还没有对话"}</strong>
            <span>{query ? "换个关键词试试" : "点击右上角开始新对话"}</span>
          </div>
        )}
        {sections.map((section) => {
          const collapsed = collapsedSections.has(section.id);
          return (
            <section className="conversation-section" key={section.id}>
              <button
                className="conversation-section-header"
                type="button"
                aria-expanded={!collapsed}
                onClick={() => toggleSection(section.id)}
              >
                <Icon name="agent" size={14} />
                <span>{SECTION_LABELS[section.id]}</span>
                <small>{section.items.length}</small>
                <Icon
                  name="chevron-down"
                  size={14}
                  className={`section-chevron${collapsed ? " collapsed" : ""}`}
                />
              </button>
              <div className={`section-body${collapsed ? " collapsed" : ""}`}>
                {section.items.map((conversation) => {
                  const active = conversationKey(conversation) === conversationKey(selected);
                  const preview = conversation.summary || conversation.lastMessage || modeLabel(conversation.mode);
                  return (
                    <button
                      key={conversationKey(conversation)}
                      className={`conversation-item${active ? " active" : ""}`}
                      type="button"
                      onClick={() => onSelect(conversation)}
                    >
                      <span className="conversation-item-heading">
                        <strong>{conversation.title || "新对话"}</strong>
                        <time>{relativeDate(conversation.updatedAt)}</time>
                      </span>
                      {query && <p>{preview}</p>}
                    </button>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>

      <footer className="connection-footer">
        <span className={`connection-dot ${connectionStatus === "connecting" ? "" : connectionStatus}`} />
        <span>{STATUS_LABELS[connectionStatus]}</span>
      </footer>
    </aside>
  );
}
