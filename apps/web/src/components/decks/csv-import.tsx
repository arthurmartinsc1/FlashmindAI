"use client";

import { useRef, useState } from "react";
import { Upload, FileText, X, CheckCircle2, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";

interface CSVImportProps {
  onImport: (file: File) => Promise<{ imported_count: number; skipped_count: number }>;
}

type Status = { imported: number; skipped: number } | null;

export function CSVImport({ onImport }: CSVImportProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<Status>(null);
  const [dragging, setDragging] = useState(false);

  function pick(f: File) {
    setFile(f);
    setError(null);
    setResult(null);
  }

  async function handleUpload() {
    if (!file) return;
    setLoading(true);
    setError(null);
    try {
      const r = await onImport(file);
      setResult({ imported: r.imported_count, skipped: r.skipped_count });
      setFile(null);
    } catch {
      setError("Falha ao importar. Verifique se o CSV tem as colunas `front` e `back`.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-3">
      <div
        className={`relative flex flex-col items-center justify-center gap-3 rounded-xl border-2 border-dashed p-8 text-center transition-colors ${
          dragging ? "border-primary bg-primary/5" : "border-border"
        }`}
        onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragging(false);
          const f = e.dataTransfer.files[0];
          if (f) pick(f);
        }}
      >
        <Upload className="h-8 w-8 text-muted-foreground" />
        <div>
          <p className="text-sm font-medium">Arraste um CSV ou</p>
          <p className="text-xs text-muted-foreground">
            Colunas obrigatórias: <code className="rounded bg-secondary px-1">front</code>,{" "}
            <code className="rounded bg-secondary px-1">back</code>
          </p>
        </div>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => inputRef.current?.click()}
        >
          Selecionar arquivo
        </Button>
        <input
          ref={inputRef}
          type="file"
          accept=".csv,text/csv"
          className="hidden"
          onChange={(e) => e.target.files?.[0] && pick(e.target.files[0])}
        />
      </div>

      {file && (
        <div className="flex items-center gap-3 rounded-lg border border-border bg-card px-4 py-3">
          <FileText className="h-4 w-4 shrink-0 text-indigo-400" />
          <span className="flex-1 truncate text-sm">{file.name}</span>
          <button onClick={() => setFile(null)} className="text-muted-foreground hover:text-foreground">
            <X className="h-4 w-4" />
          </button>
          <Button size="sm" onClick={handleUpload} disabled={loading}>
            {loading ? "Importando…" : "Importar"}
          </Button>
        </div>
      )}

      {result && (
        <div className="flex items-center gap-2 rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-600">
          <CheckCircle2 className="h-4 w-4 shrink-0" />
          <span>
            <strong>{result.imported}</strong> cards importados
            {result.skipped > 0 && `, ${result.skipped} ignorados`}.
          </span>
        </div>
      )}

      {error && (
        <div className="flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-600">
          <AlertCircle className="h-4 w-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}
    </div>
  );
}
