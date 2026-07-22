import {
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type FormEvent,
  type KeyboardEvent,
} from "react";
import { isRecord } from "../api";
import { formatBytes, markdownToHtml, messageContent, messageTime, modeLabel } from "../format";
import type { Attachment, ChatMessage, Conversation } from "../types";
import { Icon } from "./Icon";

interface ChatPanelProps {
  conversation: Conversation | null;
  messages: ChatMessage[];
  globalError: string;
  sending: boolean;
  activeTaskId: string | null;
  clarifyTaskId: string | null;
  onOpenConversations: () => void;
  onArchive: () => void;
  onDelete: () => void;
  onSend: (text: string, attachments: Attachment[]) => Promise<boolean>;
  onCancel: () => void;
  onClearError: () => void;
  onAttachmentError: (error: unknown) => void;
}

function fileToAttachment(file: File): Promise<Attachment> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve({
      fileName: file.name,
      mimeType: file.type || "application/octet-stream",
      size: file.size,
      dataUrl: String(reader.result),
      isImage: file.type.startsWith("image/"),
    });
    reader.onerror = () => reject(reader.error ?? new Error(`无法读取 ${file.name}`));
    reader.readAsDataURL(file);
  });
}

function attachmentName(attachment: Record<string, unknown>): string {
  return String(attachment.fileName ?? attachment.name ?? "附件");
}

function attachmentImage(attachment: Record<string, unknown>): string {
  const source = String(attachment.dataUrl ?? attachment.url ?? "");
  const mimeType = String(attachment.mimeType ?? attachment.type ?? "");
  const isImage = attachment.isImage === true
    || mimeType.startsWith("image/")
    || source.startsWith("data:image/")
    || /\.(avif|gif|jpe?g|png|webp)(?:[?#]|$)/i.test(source);
  return isImage && (source.startsWith("data:image/") || source.startsWith("https://") || source.startsWith("http://"))
    ? source
    : "";
}

function MessageAttachments({ attachments }: { attachments: Record<string, unknown>[] }) {
  if (!attachments.length) return null;
  return (
    <div className="message-attachments">
      {attachments.map((attachment, index) => {
        const image = attachmentImage(attachment);
        const name = attachmentName(attachment);
        return image ? (
          <img className="message-image" src={image} alt={name} key={`${name}-${index}`} />
        ) : (
          <span className="attachment-chip" key={`${name}-${index}`}>
            <Icon name="file" size={15} />
            <span>{name}</span>
          </span>
        );
      })}
    </div>
  );
}

function statusLabel(status: unknown): string {
  return ({
    running: "运行中",
    completed: "已完成",
    success: "已完成",
    error: "失败",
    cancelled: "已停止",
  } as Record<string, string>)[String(status)] ?? String(status || "已完成");
}

function Message({ message }: { message: ChatMessage }) {
  const content = messageContent(message);
  const isUser = Number(message.user) === 1;
  const rawCard = isRecord(content.cardData) ? content.cardData : null;
  const card = rawCard ?? content;
  const attachments = Array.isArray(content.attachments)
    ? content.attachments.filter(isRecord)
    : [];
  const reasoning = String(message.reasoning_content ?? message.reasoningContent ?? "").trim();
  const classes = `message-row ${isUser ? "user" : "assistant"}${message.isError ? " error" : ""}`;

  if (Number(message.type) === 2 || rawCard) {
    const title = card.toolTitle ?? card.title ?? card.toolType ?? card.type ?? "工具运行";
    const status = card.status ?? (message.isLoading ? "running" : "completed");
    return (
      <article className={`${classes} card-message`}>
        <div className="message-content">
          <details className="tool-message" open={status === "running"}>
            <summary>
              <span className="tool-icon"><Icon name="workspace" size={16} /></span>
              <span className="tool-heading">
                <strong>{String(title)}</strong>
                <small>Agent 工具调用</small>
              </span>
              <span className={`tool-status ${String(status)}`}>{statusLabel(status)}</span>
            </summary>
            <div className="tool-detail">
              <pre>{JSON.stringify(card, null, 2)}</pre>
            </div>
          </details>
        </div>
      </article>
    );
  }

  const text = String(content.text ?? "");
  return (
    <article className={classes}>
      <div className="message-content">
        {reasoning && (
          <details className="message-reasoning">
            <summary>思考过程</summary>
            <div dangerouslySetInnerHTML={{ __html: markdownToHtml(reasoning) }} />
          </details>
        )}
        {(text || message.isLoading) && (
          <div
            className="message-text"
            dangerouslySetInnerHTML={{
              __html: markdownToHtml(text || "正在思考…"),
            }}
          />
        )}
        <MessageAttachments attachments={attachments} />
      </div>
    </article>
  );
}

export function ChatPanel({
  conversation,
  messages,
  globalError,
  sending,
  activeTaskId,
  clarifyTaskId,
  onOpenConversations,
  onArchive,
  onDelete,
  onSend,
  onCancel,
  onClearError,
  onAttachmentError,
}: ChatPanelProps) {
  const [draft, setDraft] = useState("");
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  const messageListRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const attachmentInputRef = useRef<HTMLInputElement>(null);
  const sortedMessages = [...messages].sort((left, right) => messageTime(left) - messageTime(right));
  const isProcessing = sending || Boolean(activeTaskId && !clarifyTaskId);
  const canSend = !isProcessing && (clarifyTaskId ? Boolean(draft.trim()) : Boolean(draft.trim() || attachments.length));

  useEffect(() => {
    const list = messageListRef.current;
    if (list) list.scrollTop = list.scrollHeight;
  }, [messages, activeTaskId]);

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.style.height = "auto";
    textarea.style.height = `${Math.min(textarea.scrollHeight, 96)}px`;
  }, [draft]);

  async function submit(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault();
    if (!canSend) return;
    onClearError();
    const sent = await onSend(draft.trim(), attachments);
    if (sent) {
      setDraft("");
      setAttachments([]);
    }
  }

  function handleKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      void submit();
    }
  }

  async function addAttachments(event: ChangeEvent<HTMLInputElement>) {
    const files = [...(event.target.files ?? [])];
    event.target.value = "";
    if (!files.length) return;
    try {
      const nextAttachments = await Promise.all(files.map(fileToAttachment));
      setAttachments((current) => [...current, ...nextAttachments]);
    } catch (error) {
      onAttachmentError(error);
    }
  }

  return (
    <section className="chat-pane">
      <header className="chat-app-bar">
        <button
          className="appbar-icon menu-trigger"
          type="button"
          aria-label="打开对话列表"
          onClick={onOpenConversations}
        >
          <Icon name="menu" size={20} />
        </button>
        <div className="chat-island" title={conversation?.title || "Agent"}>
          <span className="chat-island-active"><Icon name="agent" size={16} /></span>
          <span>{conversation ? modeLabel(conversation.mode) : "Agent"}</span>
        </div>
        <div className="chat-header-actions">
          <button
            className="appbar-icon"
            type="button"
            aria-label={conversation?.isArchived ? "取消归档" : "归档对话"}
            title={conversation?.isArchived ? "取消归档" : "归档对话"}
            disabled={!conversation}
            onClick={onArchive}
          >
            <Icon name="archive" size={18} />
          </button>
          <button
            className="appbar-icon danger"
            type="button"
            aria-label="删除对话"
            title="删除对话"
            disabled={!conversation}
            onClick={onDelete}
          >
            <Icon name="trash" size={18} />
          </button>
        </div>
      </header>

      {globalError && <div className="global-error" role="alert">{globalError}</div>}

      <div className="message-list" aria-live="polite" ref={messageListRef}>
        {!sortedMessages.length && (
          <div className="empty-state">
            <div className="empty-greeting">
              <p>你好👋，我是小万</p>
              <p>我可以帮助你 <strong>探索</strong></p>
            </div>
          </div>
        )}
        {sortedMessages.map((message, index) => (
          <Message message={message} key={String(message.id ?? `${messageTime(message)}-${index}`)} />
        ))}
      </div>

      <div className="composer-region">
        {clarifyTaskId && (
          <div className="clarify-banner">Agent 正在等待你的补充说明，发送下一条消息后继续。</div>
        )}
        <form className="composer" onSubmit={(event) => void submit(event)}>
          {!!attachments.length && (
            <div className="attachment-list">
              {attachments.map((attachment, index) => (
                <div className={`composer-attachment${attachment.isImage ? " image" : ""}`} key={`${attachment.fileName}-${index}`}>
                  {attachment.isImage ? (
                    <img src={attachment.dataUrl} alt={attachment.fileName} />
                  ) : (
                    <>
                      <Icon name="file" size={16} />
                      <span>
                        <strong>{attachment.fileName}</strong>
                        <small>{formatBytes(attachment.size)}</small>
                      </span>
                    </>
                  )}
                  <button
                    type="button"
                    aria-label={`移除 ${attachment.fileName}`}
                    onClick={() => setAttachments((current) => current.filter((_, itemIndex) => itemIndex !== index))}
                  >
                    <Icon name="x" size={12} />
                  </button>
                </div>
              ))}
            </div>
          )}
          <textarea
            ref={textareaRef}
            rows={1}
            placeholder="请输入内容"
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            onKeyDown={handleKeyDown}
          />
          <div className="composer-actions">
            <button
              className="composer-icon-button"
              type="button"
              aria-label="添加附件"
              title="添加附件"
              onClick={() => attachmentInputRef.current?.click()}
            >
              <Icon name="paperclip" size={20} />
            </button>
            <input ref={attachmentInputRef} type="file" multiple hidden onChange={(event) => void addAttachments(event)} />
            <span className="composer-hint">Enter 发送 · Shift + Enter 换行</span>
            {activeTaskId && !clarifyTaskId ? (
              <button className="send-button stop" type="button" aria-label="停止" title="停止" onClick={onCancel}>
                <Icon name="square" size={18} />
              </button>
            ) : (
              <button className={`send-button${sending ? " loading" : ""}`} type="submit" aria-label="发送" disabled={!canSend}>
                <Icon name="arrow-up" size={18} />
              </button>
            )}
          </div>
        </form>
      </div>
    </section>
  );
}
