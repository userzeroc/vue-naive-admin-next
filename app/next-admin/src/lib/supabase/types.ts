/**
 * Hand-written Supabase database types for the first migration pass.
 *
 * Once the Supabase schema is stable, replace this file with generated types:
 * supabase gen types typescript --project-id <project-id>
 */

export type PermissionType = "MENU" | "BUTTON";
export type HttpMethod = "GET" | "POST" | "PATCH" | "PUT" | "DELETE";

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

type TableDefinition<Row, Insert = Row, Update = Partial<Insert>> = {
  Row: Row;
  Insert: Insert;
  Update: Update;
  Relationships: never[];
};

export type Database = {
  public: {
    Tables: {
      profiles: TableDefinition<
        {
          id: string;
          username: string | null;
          nick_name: string | null;
          gender: number | null;
          avatar: string | null;
          address: string | null;
          email: string | null;
          enable: boolean;
          current_role_id: number | null;
          created_at: string;
          updated_at: string;
        },
        {
          id: string;
          username?: string | null;
          nick_name?: string | null;
          gender?: number | null;
          avatar?: string | null;
          address?: string | null;
          email?: string | null;
          enable?: boolean;
          current_role_id?: number | null;
          created_at?: string;
          updated_at?: string;
        }
      >;
      roles: TableDefinition<
        {
          id: number;
          code: string;
          name: string;
          enable: boolean;
          created_at: string;
          updated_at: string;
        },
        {
          id?: number;
          code: string;
          name: string;
          enable?: boolean;
          created_at?: string;
          updated_at?: string;
        }
      >;
      permissions: TableDefinition<
        {
          id: number;
          parent_id: number | null;
          code: string;
          name: string;
          type: PermissionType;
          path: string | null;
          redirect: string | null;
          icon: string | null;
          component: string | null;
          layout: string | null;
          keep_alive: boolean;
          method: HttpMethod | null;
          description: string | null;
          order: number;
          show: boolean;
          enable: boolean;
          created_at: string;
          updated_at: string;
        },
        {
          id?: number;
          parent_id?: number | null;
          code: string;
          name: string;
          type: PermissionType;
          path?: string | null;
          redirect?: string | null;
          icon?: string | null;
          component?: string | null;
          layout?: string | null;
          keep_alive?: boolean;
          method?: HttpMethod | null;
          description?: string | null;
          order?: number;
          show?: boolean;
          enable?: boolean;
          created_at?: string;
          updated_at?: string;
        }
      >;
      user_roles: TableDefinition<
        {
          user_id: string;
          role_id: number;
          created_at: string;
        },
        {
          user_id: string;
          role_id: number;
          created_at?: string;
        }
      >;
      role_permissions: TableDefinition<
        {
          role_id: number;
          permission_id: number;
          created_at: string;
        },
        {
          role_id: number;
          permission_id: number;
          created_at?: string;
        }
      >;
    };
    Views: Record<string, never>;
    Functions: {
      get_current_user_permissions: {
        Args: Record<string, never>;
        Returns: Database["public"]["Tables"]["permissions"]["Row"][];
      };
      get_menu_tree: {
        Args: Record<string, never>;
        Returns: Json;
      };
      validate_menu_path: {
        Args: { path_to_check: string };
        Returns: boolean;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
