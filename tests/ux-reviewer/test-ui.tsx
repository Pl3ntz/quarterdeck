// Signup + account card — seeded with 8 UX/accessibility issues (obvious + subtle)
// for the ux-reviewer stability fixture. Not wired into any build.
import { useState } from "react"

const BRAND = "#6c63ff"

export function AccountCard() {
  const [email, setEmail] = useState("")
  const [pwd, setPwd] = useState("")
  const [error, setError] = useState("")

  function submit() {
    if (!email.includes("@")) {
      setError("Invalid email")
      return
    }
    setError("")
  }

  return (
    <div style={{ minHeight: "100vh", padding: 16 }}>
      {/* ISSUE 1 (obvious): avatar image has no alt text — WCAG 1.1.1 */}
      <img src="/avatar.png" width={64} height={64} />

      <h1 style={{ marginLeft: 12, textAlign: "left" }}>Your account</h1>

      {/* ISSUE 2 (obvious): clickable div instead of <button> — not keyboard reachable */}
      <div onClick={() => submit()} style={{ background: BRAND, color: "#fff", padding: 12 }}>
        Save changes
      </div>

      {/* ISSUE 3 (obvious): input labelled only by placeholder — no <label> */}
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />

      {/* ISSUE 4 (subtle): password field blocks paste — breaks password managers, WCAG 3.3.8 */}
      <input
        type="password"
        value={pwd}
        onChange={(e) => setPwd(e.target.value)}
        onPaste={(e) => e.preventDefault()}
      />

      {/* ISSUE 5 (subtle): error conveyed by color alone — no icon/text marker, WCAG 1.4.1 */}
      {error && <span style={{ color: "red" }}>{error}</span>}

      {/* ISSUE 6 (obvious): icon-only button with no accessible name */}
      <button onClick={() => setEmail("")}>
        <svg width={16} height={16} viewBox="0 0 16 16">
          <path d="M4 4l8 8M12 4l-8 8" stroke="currentColor" />
        </svg>
      </button>

      {/* ISSUE 7 (subtle): touch target well under 24x24 CSS px — WCAG 2.5.8 */}
      <a href="/help" style={{ display: "inline-block", width: 16, height: 16 }}>
        ?
      </a>

      {/* ISSUE 8 (subtle): custom modal via role="dialog" with no focus management / native <dialog> */}
      <div role="dialog" aria-label="Confirm" style={{ position: "fixed", inset: 0 }}>
        <p>Are you sure?</p>
        <button>Yes</button>
      </div>
    </div>
  )
}
