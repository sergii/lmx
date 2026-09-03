import type { ImgHTMLAttributes } from "react"

export default function AppLogoIcon({
  className,
  ...props
}: ImgHTMLAttributes<HTMLImageElement>) {
  return (
    <img
      aria-hidden="true"
      alt=""
      className={`object-contain ${className ?? ""}`}
      src="/hiredo-logo.png"
      {...props}
    />
  )
}
