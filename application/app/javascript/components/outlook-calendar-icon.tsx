import type { SVGAttributes } from "react"

export default function OutlookCalendarIcon(props: SVGAttributes<SVGElement>) {
  return (
    <svg
      aria-hidden="true"
      fill="none"
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path d="M9 5.5h9.5v13H9z" fill="#28A8EA" />
      <path d="M11 8h7.5v8.5H11z" fill="#0078D4" />
      <path d="m11 8 3.75 3L18.5 8" stroke="white" strokeWidth="1.25" />
      <path d="M4 4.5h7v15H4z" fill="#0078D4" />
      <path
        d="M7.2 8.1c-1.2 0-2 .9-2 3.9s.8 3.9 2 3.9 2-.9 2-3.9-.8-3.9-2-3.9Zm0 6.3c-.5 0-.8-.6-.8-2.4s.3-2.4.8-2.4.8.6.8 2.4-.3 2.4-.8 2.4Z"
        fill="white"
      />
    </svg>
  )
}
