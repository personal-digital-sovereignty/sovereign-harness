/**
 * Sovereign Harness — adaptador do guard para o OpenCode.
 *
 * O OpenCode não tem hook de processo como o Claude Code e o Codex; tem plugins
 * TS com `tool.execute.before`. Este plugin chama o MESMO motor
 * (`harness_guard.py checar`) que os outros agentes usam e, se o veredito for
 * "bloquear", lança erro — a ferramenta não executa e o motivo volta ao modelo.
 *
 * Onde o guard é procurado (o primeiro que existir):
 *   1. $HARNESS_GUARD
 *   2. <raiz do projeto>/.harness/harness_guard.py   (instalado pelo install.sh)
 *   3. ao lado deste arquivo
 *
 * Sem python3 ou sem o guard, o plugin AVISA alto no início e não bloqueia nada:
 * os gates do git (pre-commit/pre-push/merge gate) continuam valendo.
 */
import type { Plugin } from "@opencode-ai/plugin"
import { existsSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

type Veredito = {
  decisao: "liberar" | "avisar" | "bloquear"
  mensagem?: string
  avisos?: string[]
}

const EDITORES = new Set(["edit", "write", "multiedit"])
const PATCH = new Set(["patch", "apply_patch"])

function acharGuard(raiz: string): string | undefined {
  const aqui = dirname(fileURLToPath(import.meta.url))
  const candidatos = [process.env.HARNESS_GUARD, join(raiz, ".harness", "harness_guard.py"), join(aqui, "harness_guard.py")]
  return candidatos.find((c): c is string => typeof c === "string" && c.length > 0 && existsSync(c))
}

function alvos(ferramenta: string, args: Record<string, unknown>): string[][] {
  const t = ferramenta.toLowerCase()
  const arquivo = typeof args.filePath === "string" ? args.filePath : undefined
  if (t === "bash" && typeof args.command === "string") return [["--cmd", args.command]]
  if (EDITORES.has(t) && arquivo) return [["--arquivo", arquivo, "--acao", "editar"]]
  if (t === "read" && arquivo) return [["--arquivo", arquivo, "--acao", "ler"]]
  if (PATCH.has(t)) {
    const texto = String(args.patchText ?? args.patch ?? args.input ?? "")
    const caminhos = [...texto.matchAll(/^\*\*\* (?:Update|Add|Delete) File: (.+)$/gm)].map((m) => m[1].trim())
    return caminhos.map((c) => ["--arquivo", c, "--acao", "editar"])
  }
  return []
}

export const SovereignHarness: Plugin = async ({ directory, worktree, $ }) => {
  const raiz = worktree || directory
  const guard = acharGuard(raiz)
  if (!guard) {
    console.error(
      "⚠️  sovereign-harness: harness_guard.py não encontrado (HARNESS_GUARD, .harness/ ou ao lado do plugin). " +
        "Guardrails do agente DESLIGADOS nesta sessão; os gates do git continuam valendo.",
    )
    return {}
  }

  return {
    "tool.execute.before": async (input, output) => {
      const args = (output.args ?? {}) as Record<string, unknown>
      const cwd = typeof args.workdir === "string" ? args.workdir : directory
      for (const alvo of alvos(input.tool, args)) {
        const r = await $`python3 ${guard} checar ${alvo} --cwd ${cwd}`.quiet().nothrow()
        if (r.exitCode !== 0) {
          console.error(`⚠️  sovereign-harness: o guard falhou (exit ${r.exitCode}): ${r.stderr.toString().trim()}`)
          return
        }
        const v = JSON.parse(r.stdout.toString()) as Veredito
        if (v.decisao === "bloquear") throw new Error(v.mensagem ?? "harness: ação bloqueada")
        for (const aviso of v.avisos ?? []) console.error(`⚠️  harness: ${aviso}`)
      }
    },
  }
}

export default SovereignHarness
