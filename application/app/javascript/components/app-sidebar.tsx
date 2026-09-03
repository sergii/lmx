import { Link, usePage } from "@inertiajs/react"
import {
  BriefcaseBusiness,
  Building2,
  ChevronsUpDown,
  FolderKanban,
  LayoutGrid,
  ListTodo,
  CalendarDays,
  PanelsTopLeft,
  UserPlus,
  UsersRound,
} from "lucide-react"

import { NavMain } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import type { NavItem, SharedProps } from "@/types"

import AppLogo from "./app-logo"

const mainNavItems: NavItem[] = [
  {
    title: "Home",
    href: "/home",
    icon: LayoutGrid,
  },
  {
    title: "Tasks",
    href: "/tasks",
    icon: ListTodo,
  },
  {
    title: "Meetings",
    href: "/meetings",
    icon: CalendarDays,
  },
  {
    title: "Clients",
    href: "/client_companies",
    icon: Building2,
  },
  {
    title: "Projects",
    href: "/projects",
    icon: FolderKanban,
  },
  {
    title: "Jobs",
    href: "/jobs",
    icon: BriefcaseBusiness,
  },
  {
    title: "Pipeline",
    href: "/pipeline",
    icon: PanelsTopLeft,
  },
  {
    title: "Candidates",
    href: "/candidates",
    icon: UsersRound,
  },
]

const clientNavItems: NavItem[] = [
  {
    title: "Presented candidates",
    href: "/client/applications",
    icon: UsersRound,
  },
]

export function AppSidebar() {
  const { props } = usePage<SharedProps & Record<string, unknown>>()
  const navigation = props.portal?.client ? clientNavItems : mainNavItems

  return (
    <Sidebar collapsible="icon" variant="inset">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link href="/organizations" prefetch>
                <AppLogo
                  name={props.organization?.name}
                  logoUrl={props.organization?.logo_url}
                />
                <ChevronsUpDown className="ml-auto size-4" />
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>

      <SidebarContent>
        <NavMain items={navigation} />
      </SidebarContent>

      <SidebarFooter>
        {!props.portal?.client && props.permissions?.workspace_admin && (
          <>
            <SidebarMenu className="mb-2 px-2">
              <SidebarMenuItem>
                <SidebarMenuButton
                  asChild
                  tooltip={{ children: "Invite team members" }}
                >
                  <Link href="/settings/team" prefetch>
                    <UserPlus />
                    <span>Invite team members</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
            <NavMain
              items={[
                {
                  title: "Workspace settings",
                  href: "/settings/workspace",
                  icon: Building2,
                },
              ]}
            />
          </>
        )}
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
