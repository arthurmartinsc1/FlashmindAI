import ReactMarkdown from "react-markdown";
import type { TextBlockContent } from "@/types/api";

const components = {
  p:      ({ children }: { children?: React.ReactNode }) => <p className="mb-3 leading-relaxed last:mb-0">{children}</p>,
  strong: ({ children }: { children?: React.ReactNode }) => <strong className="font-semibold text-foreground">{children}</strong>,
  em:     ({ children }: { children?: React.ReactNode }) => <em className="italic">{children}</em>,
  h1:     ({ children }: { children?: React.ReactNode }) => <h1 className="mb-2 mt-4 text-xl font-bold first:mt-0">{children}</h1>,
  h2:     ({ children }: { children?: React.ReactNode }) => <h2 className="mb-2 mt-3 text-lg font-semibold first:mt-0">{children}</h2>,
  h3:     ({ children }: { children?: React.ReactNode }) => <h3 className="mb-1.5 mt-2 text-base font-semibold first:mt-0">{children}</h3>,
  ul:     ({ children }: { children?: React.ReactNode }) => <ul className="my-2 ml-5 list-disc space-y-1">{children}</ul>,
  ol:     ({ children }: { children?: React.ReactNode }) => <ol className="my-2 ml-5 list-decimal space-y-1">{children}</ol>,
  li:     ({ children }: { children?: React.ReactNode }) => <li className="leading-relaxed">{children}</li>,
  code:   ({ children }: { children?: React.ReactNode }) => (
    <code className="rounded bg-secondary px-1.5 py-0.5 font-mono text-[0.8em]">{children}</code>
  ),
  pre:    ({ children }: { children?: React.ReactNode }) => (
    <pre className="my-3 overflow-x-auto rounded-lg bg-secondary p-4 font-mono text-sm">{children}</pre>
  ),
  blockquote: ({ children }: { children?: React.ReactNode }) => (
    <blockquote className="my-3 border-l-2 border-primary pl-4 text-muted-foreground">{children}</blockquote>
  ),
};

export function BlockText({ content }: { content: TextBlockContent }) {
  return (
    <div className="text-sm leading-relaxed text-foreground">
      <ReactMarkdown components={components as never}>{content.body}</ReactMarkdown>
    </div>
  );
}
