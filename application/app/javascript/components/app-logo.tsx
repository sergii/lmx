export default function AppLogo({
  name,
  logoUrl,
}: {
  name?: string
  logoUrl?: string | null
}) {
  const workspaceName = name ?? import.meta.env.VITE_APP_NAME ?? "Hire.do"

  return (
    <>
      <div className="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center overflow-hidden rounded-full text-xs font-semibold">
        {logoUrl ? (
          <img
            src={logoUrl}
            alt=""
            className="size-full bg-white object-contain p-1"
          />
        ) : (
          workspaceName.slice(0, 1).toUpperCase()
        )}
      </div>
      <div className="ml-1 grid flex-1 text-left text-sm">
        <span className="mb-0.5 truncate leading-tight font-semibold">
          {workspaceName}
        </span>
      </div>
    </>
  )
}
