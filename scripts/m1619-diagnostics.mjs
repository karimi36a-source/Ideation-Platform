// Test harness diagnostics only. Redact before truncating or emitting output.
export function sanitizeDiagnostic(value,secrets=[]){
 let text=String(value);
 for(const secret of secrets.filter(value=>typeof value==='string'&&value.length>=4).sort((a,b)=>b.length-a.length))text=text.split(secret).join('[REDACTED]');
 return text.replace(/(?:postgres(?:ql)?|https?):\/\/[^\s"'<>]+/gi,'[REDACTED_URL]')
  .replace(/\bBearer\s+[^\s"']+/gi,'Bearer [REDACTED]')
  .replace(/\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g,'[REDACTED_JWT]')
  .replace(/((?:authorization|password|secret|api[_-]?key|access[_-]?token|refresh[_-]?token)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;}]+)/gi,'$1[REDACTED]')
  .replace(/[\x00-\x08\x0B-\x1F\x7F]/g,'').slice(-6000);
}
