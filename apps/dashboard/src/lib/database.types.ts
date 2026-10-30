/** Generated from Supabase project nqfjudwncistygsmcgrq on 2026-10-30.
 *  Do not edit by hand — refresh with `supabase gen types` or MCP generate_typescript_types.
 *  Wire into the desk with: createClient<Database>(url, key)
 */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18";
  };
  public: {
    Tables: {
      audit_log: {
        Row: {
          action: string;
          actor_id: string | null;
          actor_role: string;
          at: string;
          changed: Json;
          id: number;
          row_pk: string;
          school_id: string | null;
          student_id: string | null;
          table_name: string;
        };
        Insert: {
          action: string;
          actor_id?: string | null;
          actor_role?: string;
          at?: string;
          changed?: Json;
          id?: never;
          row_pk: string;
          school_id?: string | null;
          student_id?: string | null;
          table_name: string;
        };
        Update: {
          action?: string;
          actor_id?: string | null;
          actor_role?: string;
          at?: string;
          changed?: Json;
          id?: never;
          row_pk?: string;
          school_id?: string | null;
          student_id?: string | null;
          table_name?: string;
        };
        Relationships: [];
      };
      billing_customers: {
        Row: {
          active: boolean;
          created_at: string;
          display_name: string;
          email: string;
          id: string;
          phone: string;
          qbo_customer_id: string | null;
          qbo_sync_token: string | null;
          qbo_updated_at: string | null;
          school_id: string;
          student_id: string | null;
          sync_error: string | null;
          sync_status: string;
          updated_at: string;
        };
        Insert: {
          active?: boolean;
          created_at?: string;
          display_name: string;
          email?: string;
          id?: string;
          phone?: string;
          qbo_customer_id?: string | null;
          qbo_sync_token?: string | null;
          qbo_updated_at?: string | null;
          school_id: string;
          student_id?: string | null;
          sync_error?: string | null;
          sync_status?: string;
          updated_at?: string;
        };
        Update: {
          active?: boolean;
          created_at?: string;
          display_name?: string;
          email?: string;
          id?: string;
          phone?: string;
          qbo_customer_id?: string | null;
          qbo_sync_token?: string | null;
          qbo_updated_at?: string | null;
          school_id?: string;
          student_id?: string | null;
          sync_error?: string | null;
          sync_status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "billing_customers_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "billing_customers_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      cars: {
        Row: {
          active: boolean;
          assigned_user_id: string | null;
          color: string;
          created_at: string;
          dual_control: boolean;
          id: string;
          ins_due: string | null;
          inspect_due: string | null;
          model: string;
          name: string;
          notes: string;
          odo_miles: number;
          plate: string;
          reg_due: string | null;
          school_id: string;
          service_due: string | null;
        };
        Insert: {
          active?: boolean;
          assigned_user_id?: string | null;
          color?: string;
          created_at?: string;
          dual_control?: boolean;
          id?: string;
          ins_due?: string | null;
          inspect_due?: string | null;
          model?: string;
          name: string;
          notes?: string;
          odo_miles?: number;
          plate?: string;
          reg_due?: string | null;
          school_id: string;
          service_due?: string | null;
        };
        Update: {
          active?: boolean;
          assigned_user_id?: string | null;
          color?: string;
          created_at?: string;
          dual_control?: boolean;
          id?: string;
          ins_due?: string | null;
          inspect_due?: string | null;
          model?: string;
          name?: string;
          notes?: string;
          odo_miles?: number;
          plate?: string;
          reg_due?: string | null;
          school_id?: string;
          service_due?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "cars_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      device_push_tokens: {
        Row: {
          auth: string | null;
          created_at: string;
          endpoint: string | null;
          id: string;
          p256dh: string | null;
          platform: string;
          token: string;
          updated_at: string;
          user_agent: string | null;
          user_id: string;
        };
        Insert: {
          auth?: string | null;
          created_at?: string;
          endpoint?: string | null;
          id?: string;
          p256dh?: string | null;
          platform: string;
          token: string;
          updated_at?: string;
          user_agent?: string | null;
          user_id: string;
        };
        Update: {
          auth?: string | null;
          created_at?: string;
          endpoint?: string | null;
          id?: string;
          p256dh?: string | null;
          platform?: string;
          token?: string;
          updated_at?: string;
          user_agent?: string | null;
          user_id?: string;
        };
        Relationships: [];
      };
      drive_route_chunks: {
        Row: {
          chunk_no: number;
          created_at: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Insert: {
          chunk_no: number;
          created_at?: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Update: {
          chunk_no?: number;
          created_at?: string;
          drive_id?: string;
          first_at?: string;
          last_at?: string;
          point_count?: number;
          polyline?: string;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "drive_route_chunks_drive_id_fkey";
            columns: ["drive_id"];
            isOneToOne: false;
            referencedRelation: "drives";
            referencedColumns: ["id"];
          },
        ];
      };
      drive_route_chunks_p0: {
        Row: {
          chunk_no: number;
          created_at: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Insert: {
          chunk_no: number;
          created_at?: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Update: {
          chunk_no?: number;
          created_at?: string;
          drive_id?: string;
          first_at?: string;
          last_at?: string;
          point_count?: number;
          polyline?: string;
          student_id?: string;
        };
        Relationships: [];
      };
      drive_route_chunks_p1: {
        Row: {
          chunk_no: number;
          created_at: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Insert: {
          chunk_no: number;
          created_at?: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Update: {
          chunk_no?: number;
          created_at?: string;
          drive_id?: string;
          first_at?: string;
          last_at?: string;
          point_count?: number;
          polyline?: string;
          student_id?: string;
        };
        Relationships: [];
      };
      drive_route_chunks_p2: {
        Row: {
          chunk_no: number;
          created_at: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Insert: {
          chunk_no: number;
          created_at?: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Update: {
          chunk_no?: number;
          created_at?: string;
          drive_id?: string;
          first_at?: string;
          last_at?: string;
          point_count?: number;
          polyline?: string;
          student_id?: string;
        };
        Relationships: [];
      };
      drive_route_chunks_p3: {
        Row: {
          chunk_no: number;
          created_at: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Insert: {
          chunk_no: number;
          created_at?: string;
          drive_id: string;
          first_at: string;
          last_at: string;
          point_count: number;
          polyline: string;
          student_id: string;
        };
        Update: {
          chunk_no?: number;
          created_at?: string;
          drive_id?: string;
          first_at?: string;
          last_at?: string;
          point_count?: number;
          polyline?: string;
          student_id?: string;
        };
        Relationships: [];
      };
      drive_signoffs: {
        Row: {
          device: Json;
          drive_id: string;
          id: string;
          initials: string | null;
          method: string;
          school_id: string | null;
          signed_at: string;
          signer_user_id: string | null;
          snapshot: Json;
          snapshot_sha256: string;
          student_id: string;
          supervisor_id: string | null;
          supervisor_name: string;
        };
        Insert: {
          device?: Json;
          drive_id: string;
          id?: string;
          initials?: string | null;
          method: string;
          school_id?: string | null;
          signed_at?: string;
          signer_user_id?: string | null;
          snapshot: Json;
          snapshot_sha256: string;
          student_id: string;
          supervisor_id?: string | null;
          supervisor_name: string;
        };
        Update: {
          device?: Json;
          drive_id?: string;
          id?: string;
          initials?: string | null;
          method?: string;
          school_id?: string | null;
          signed_at?: string;
          signer_user_id?: string | null;
          snapshot?: Json;
          snapshot_sha256?: string;
          student_id?: string;
          supervisor_id?: string | null;
          supervisor_name?: string;
        };
        Relationships: [
          {
            foreignKeyName: "drive_signoffs_drive_id_fkey";
            columns: ["drive_id"];
            isOneToOne: true;
            referencedRelation: "drives";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "drive_signoffs_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "drive_signoffs_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "drive_signoffs_supervisor_id_fkey";
            columns: ["supervisor_id"];
            isOneToOne: false;
            referencedRelation: "supervisors";
            referencedColumns: ["id"];
          },
        ];
      };
      drives: {
        Row: {
          app_version: string;
          conditions: string[];
          created_at: string;
          created_by: string | null;
          distance_miles: number;
          duration_minutes: number;
          end_label: string;
          ended_at: string | null;
          id: string;
          kind: string;
          local_date: string;
          locked_at: string | null;
          night_minutes: number;
          notes: string;
          route_point_count: number;
          route_polyline: string | null;
          school_id: string | null;
          skills: string[];
          source: string;
          start_label: string;
          started_at: string;
          status: string;
          student_id: string;
          supervisor_id: string | null;
          tz: string;
          updated_at: string;
          void_reason: string | null;
          weather_minutes: number;
        };
        Insert: {
          app_version?: string;
          conditions?: string[];
          created_at?: string;
          created_by?: string | null;
          distance_miles?: number;
          duration_minutes?: number;
          end_label?: string;
          ended_at?: string | null;
          id?: string;
          kind?: string;
          local_date: string;
          locked_at?: string | null;
          night_minutes?: number;
          notes?: string;
          route_point_count?: number;
          route_polyline?: string | null;
          school_id?: string | null;
          skills?: string[];
          source?: string;
          start_label?: string;
          started_at: string;
          status?: string;
          student_id: string;
          supervisor_id?: string | null;
          tz?: string;
          updated_at?: string;
          void_reason?: string | null;
          weather_minutes?: number;
        };
        Update: {
          app_version?: string;
          conditions?: string[];
          created_at?: string;
          created_by?: string | null;
          distance_miles?: number;
          duration_minutes?: number;
          end_label?: string;
          ended_at?: string | null;
          id?: string;
          kind?: string;
          local_date?: string;
          locked_at?: string | null;
          night_minutes?: number;
          notes?: string;
          route_point_count?: number;
          route_polyline?: string | null;
          school_id?: string | null;
          skills?: string[];
          source?: string;
          start_label?: string;
          started_at?: string;
          status?: string;
          student_id?: string;
          supervisor_id?: string | null;
          tz?: string;
          updated_at?: string;
          void_reason?: string | null;
          weather_minutes?: number;
        };
        Relationships: [
          {
            foreignKeyName: "drives_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "drives_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "drives_supervisor_id_fkey";
            columns: ["supervisor_id"];
            isOneToOne: false;
            referencedRelation: "supervisors";
            referencedColumns: ["id"];
          },
        ];
      };
      exports: {
        Row: {
          byte_size: number | null;
          created_at: string;
          drive_id: string | null;
          expires_at: string;
          id: string;
          kind: string;
          requested_by: string;
          school_id: string | null;
          status: string;
          storage_path: string | null;
          student_id: string;
        };
        Insert: {
          byte_size?: number | null;
          created_at?: string;
          drive_id?: string | null;
          expires_at?: string;
          id?: string;
          kind: string;
          requested_by: string;
          school_id?: string | null;
          status?: string;
          storage_path?: string | null;
          student_id: string;
        };
        Update: {
          byte_size?: number | null;
          created_at?: string;
          drive_id?: string | null;
          expires_at?: string;
          id?: string;
          kind?: string;
          requested_by?: string;
          school_id?: string | null;
          status?: string;
          storage_path?: string | null;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "exports_drive_id_fkey";
            columns: ["drive_id"];
            isOneToOne: false;
            referencedRelation: "drives";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "exports_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "exports_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      family_invites: {
        Row: {
          code_hash: string;
          code_hint: string;
          created_at: string;
          created_by: string | null;
          expires_at: string;
          id: string;
          max_uses: number;
          relationship: string;
          revoked_at: string | null;
          school_id: string | null;
          sent_to_email: string | null;
          student_id: string;
          uses: number;
        };
        Insert: {
          code_hash: string;
          code_hint: string;
          created_at?: string;
          created_by?: string | null;
          expires_at?: string;
          id?: string;
          max_uses?: number;
          relationship?: string;
          revoked_at?: string | null;
          school_id?: string | null;
          sent_to_email?: string | null;
          student_id: string;
          uses?: number;
        };
        Update: {
          code_hash?: string;
          code_hint?: string;
          created_at?: string;
          created_by?: string | null;
          expires_at?: string;
          id?: string;
          max_uses?: number;
          relationship?: string;
          revoked_at?: string | null;
          school_id?: string | null;
          sent_to_email?: string | null;
          student_id?: string;
          uses?: number;
        };
        Relationships: [
          {
            foreignKeyName: "family_invites_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "family_invites_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      family_links: {
        Row: {
          can_sign: boolean;
          created_at: string;
          id: string;
          invite_id: string | null;
          relationship: string;
          revoked_at: string | null;
          school_id: string | null;
          status: string;
          student_id: string;
          user_id: string;
        };
        Insert: {
          can_sign?: boolean;
          created_at?: string;
          id?: string;
          invite_id?: string | null;
          relationship?: string;
          revoked_at?: string | null;
          school_id?: string | null;
          status?: string;
          student_id: string;
          user_id: string;
        };
        Update: {
          can_sign?: boolean;
          created_at?: string;
          id?: string;
          invite_id?: string | null;
          relationship?: string;
          revoked_at?: string | null;
          school_id?: string | null;
          status?: string;
          student_id?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_links_invite_id_fkey";
            columns: ["invite_id"];
            isOneToOne: false;
            referencedRelation: "family_invites";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "family_links_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "family_links_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      instructor_pay_runs: {
        Row: {
          amount: number;
          created_at: string;
          created_by: string | null;
          hours: number;
          id: string;
          instructor_id: string;
          note: string;
          period_end: string;
          period_start: string;
          rate: number;
          school_id: string;
          status: string;
        };
        Insert: {
          amount?: number;
          created_at?: string;
          created_by?: string | null;
          hours?: number;
          id?: string;
          instructor_id: string;
          note?: string;
          period_end: string;
          period_start: string;
          rate?: number;
          school_id: string;
          status?: string;
        };
        Update: {
          amount?: number;
          created_at?: string;
          created_by?: string | null;
          hours?: number;
          id?: string;
          instructor_id?: string;
          note?: string;
          period_end?: string;
          period_start?: string;
          rate?: number;
          school_id?: string;
          status?: string;
        };
        Relationships: [
          {
            foreignKeyName: "instructor_pay_runs_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      invoice_lines: {
        Row: {
          amount: number;
          description: string;
          id: string;
          invoice_id: string;
          line_no: number;
          package_catalog_id: string | null;
          qbo_item_id: string | null;
          quantity: number;
          school_id: string;
          unit_price: number;
        };
        Insert: {
          amount?: number;
          description?: string;
          id?: string;
          invoice_id: string;
          line_no: number;
          package_catalog_id?: string | null;
          qbo_item_id?: string | null;
          quantity?: number;
          school_id: string;
          unit_price?: number;
        };
        Update: {
          amount?: number;
          description?: string;
          id?: string;
          invoice_id?: string;
          line_no?: number;
          package_catalog_id?: string | null;
          qbo_item_id?: string | null;
          quantity?: number;
          school_id?: string;
          unit_price?: number;
        };
        Relationships: [
          {
            foreignKeyName: "invoice_lines_invoice_id_fkey";
            columns: ["invoice_id"];
            isOneToOne: false;
            referencedRelation: "invoices";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invoice_lines_package_catalog_id_fkey";
            columns: ["package_catalog_id"];
            isOneToOne: false;
            referencedRelation: "package_catalog";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invoice_lines_package_catalog_id_fkey";
            columns: ["package_catalog_id"];
            isOneToOne: false;
            referencedRelation: "package_catalog_desk";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invoice_lines_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      invoices: {
        Row: {
          balance: number;
          created_at: string;
          created_by: string | null;
          currency: string;
          customer_id: string;
          doc_number: string | null;
          due_date: string | null;
          id: string;
          memo: string;
          qbo_invoice_id: string | null;
          qbo_sync_token: string | null;
          qbo_updated_at: string | null;
          school_id: string;
          status: string;
          student_id: string | null;
          subtotal: number;
          sync_error: string | null;
          sync_status: string;
          tax: number;
          total: number;
          txn_date: string;
          updated_at: string;
        };
        Insert: {
          balance?: number;
          created_at?: string;
          created_by?: string | null;
          currency?: string;
          customer_id: string;
          doc_number?: string | null;
          due_date?: string | null;
          id?: string;
          memo?: string;
          qbo_invoice_id?: string | null;
          qbo_sync_token?: string | null;
          qbo_updated_at?: string | null;
          school_id: string;
          status?: string;
          student_id?: string | null;
          subtotal?: number;
          sync_error?: string | null;
          sync_status?: string;
          tax?: number;
          total?: number;
          txn_date?: string;
          updated_at?: string;
        };
        Update: {
          balance?: number;
          created_at?: string;
          created_by?: string | null;
          currency?: string;
          customer_id?: string;
          doc_number?: string | null;
          due_date?: string | null;
          id?: string;
          memo?: string;
          qbo_invoice_id?: string | null;
          qbo_sync_token?: string | null;
          qbo_updated_at?: string | null;
          school_id?: string;
          status?: string;
          student_id?: string | null;
          subtotal?: number;
          sync_error?: string | null;
          sync_status?: string;
          tax?: number;
          total?: number;
          txn_date?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "invoices_customer_id_fkey";
            columns: ["customer_id"];
            isOneToOne: false;
            referencedRelation: "billing_customers";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invoices_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "invoices_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      lessons: {
        Row: {
          cancelled_at: string | null;
          car_id: string | null;
          created_at: string;
          created_by: string | null;
          drive_id: string | null;
          end_at: string;
          hours_drawn: number;
          id: string;
          instructor_id: string;
          kind: string;
          lot_id: string | null;
          meet: string;
          name: string;
          notes: string;
          package_id: string | null;
          pickup: string;
          school_id: string;
          start_at: string;
          status: string;
          student_id: string | null;
          template_id: string | null;
          topic: string;
          travel_after_minutes: number;
          travel_before_minutes: number;
          updated_at: string;
        };
        Insert: {
          cancelled_at?: string | null;
          car_id?: string | null;
          created_at?: string;
          created_by?: string | null;
          drive_id?: string | null;
          end_at: string;
          hours_drawn?: number;
          id?: string;
          instructor_id: string;
          kind?: string;
          lot_id?: string | null;
          meet?: string;
          name?: string;
          notes?: string;
          package_id?: string | null;
          pickup?: string;
          school_id: string;
          start_at: string;
          status?: string;
          student_id?: string | null;
          template_id?: string | null;
          topic?: string;
          travel_after_minutes?: number;
          travel_before_minutes?: number;
          updated_at?: string;
        };
        Update: {
          cancelled_at?: string | null;
          car_id?: string | null;
          created_at?: string;
          created_by?: string | null;
          drive_id?: string | null;
          end_at?: string;
          hours_drawn?: number;
          id?: string;
          instructor_id?: string;
          kind?: string;
          lot_id?: string | null;
          meet?: string;
          name?: string;
          notes?: string;
          package_id?: string | null;
          pickup?: string;
          school_id?: string;
          start_at?: string;
          status?: string;
          student_id?: string | null;
          template_id?: string | null;
          topic?: string;
          travel_after_minutes?: number;
          travel_before_minutes?: number;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "lessons_car_id_fkey";
            columns: ["car_id"];
            isOneToOne: false;
            referencedRelation: "cars";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lessons_drive_id_fkey";
            columns: ["drive_id"];
            isOneToOne: false;
            referencedRelation: "drives";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lessons_lot_id_fkey";
            columns: ["lot_id"];
            isOneToOne: false;
            referencedRelation: "lots";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lessons_package_id_fkey";
            columns: ["package_id"];
            isOneToOne: false;
            referencedRelation: "student_packages";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lessons_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lessons_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lessons_template_id_fkey";
            columns: ["template_id"];
            isOneToOne: false;
            referencedRelation: "slot_templates";
            referencedColumns: ["id"];
          },
        ];
      };
      lots: {
        Row: {
          created_at: string;
          id: string;
          is_default: boolean;
          lat: number | null;
          lng: number | null;
          name: string;
          school_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          is_default?: boolean;
          lat?: number | null;
          lng?: number | null;
          name: string;
          school_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          is_default?: boolean;
          lat?: number | null;
          lng?: number | null;
          name?: string;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "lots_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      package_catalog: {
        Row: {
          active: boolean;
          hours: number;
          id: string;
          kind: string;
          name: string;
          price: number;
          school_id: string;
        };
        Insert: {
          active?: boolean;
          hours: number;
          id?: string;
          kind?: string;
          name: string;
          price?: number;
          school_id: string;
        };
        Update: {
          active?: boolean;
          hours?: number;
          id?: string;
          kind?: string;
          name?: string;
          price?: number;
          school_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "package_catalog_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      payments: {
        Row: {
          amount: number;
          created_at: string;
          created_by: string | null;
          customer_id: string;
          id: string;
          invoice_id: string | null;
          method: string;
          qbo_payment_id: string | null;
          qbo_sync_token: string | null;
          qbo_updated_at: string | null;
          received_on: string;
          reference: string;
          school_id: string;
          student_id: string | null;
          sync_error: string | null;
          sync_status: string;
          updated_at: string;
        };
        Insert: {
          amount: number;
          created_at?: string;
          created_by?: string | null;
          customer_id: string;
          id?: string;
          invoice_id?: string | null;
          method?: string;
          qbo_payment_id?: string | null;
          qbo_sync_token?: string | null;
          qbo_updated_at?: string | null;
          received_on?: string;
          reference?: string;
          school_id: string;
          student_id?: string | null;
          sync_error?: string | null;
          sync_status?: string;
          updated_at?: string;
        };
        Update: {
          amount?: number;
          created_at?: string;
          created_by?: string | null;
          customer_id?: string;
          id?: string;
          invoice_id?: string | null;
          method?: string;
          qbo_payment_id?: string | null;
          qbo_sync_token?: string | null;
          qbo_updated_at?: string | null;
          received_on?: string;
          reference?: string;
          school_id?: string;
          student_id?: string | null;
          sync_error?: string | null;
          sync_status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "payments_customer_id_fkey";
            columns: ["customer_id"];
            isOneToOne: false;
            referencedRelation: "billing_customers";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "payments_invoice_id_fkey";
            columns: ["invoice_id"];
            isOneToOne: false;
            referencedRelation: "invoices";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "payments_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "payments_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      profiles: {
        Row: {
          account_type: string;
          created_at: string;
          full_name: string;
          id: string;
          notify_email: boolean;
          phone: string;
          updated_at: string;
        };
        Insert: {
          account_type?: string;
          created_at?: string;
          full_name?: string;
          id: string;
          notify_email?: boolean;
          phone?: string;
          updated_at?: string;
        };
        Update: {
          account_type?: string;
          created_at?: string;
          full_name?: string;
          id?: string;
          notify_email?: boolean;
          phone?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      qbo_connections: {
        Row: {
          access_expires_at: string | null;
          company_name: string;
          connected_at: string;
          connected_by: string | null;
          environment: string;
          last_error: string | null;
          last_sync_at: string | null;
          realm_id: string;
          refresh_expires_at: string | null;
          school_id: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          access_expires_at?: string | null;
          company_name?: string;
          connected_at?: string;
          connected_by?: string | null;
          environment?: string;
          last_error?: string | null;
          last_sync_at?: string | null;
          realm_id: string;
          refresh_expires_at?: string | null;
          school_id: string;
          status?: string;
          updated_at?: string;
        };
        Update: {
          access_expires_at?: string | null;
          company_name?: string;
          connected_at?: string;
          connected_by?: string | null;
          environment?: string;
          last_error?: string | null;
          last_sync_at?: string | null;
          realm_id?: string;
          refresh_expires_at?: string | null;
          school_id?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "qbo_connections_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: true;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      reservations: {
        Row: {
          car_id: string | null;
          created_at: string;
          decline_reason: string;
          end_at: string;
          id: string;
          instructor_id: string;
          kind: string;
          lesson_id: string | null;
          meet: string;
          note: string;
          school_id: string;
          start_at: string;
          status: string;
          student_id: string;
          template_id: string | null;
          travel_after_minutes: number;
          travel_before_minutes: number;
        };
        Insert: {
          car_id?: string | null;
          created_at?: string;
          decline_reason?: string;
          end_at: string;
          id?: string;
          instructor_id: string;
          kind?: string;
          lesson_id?: string | null;
          meet?: string;
          note?: string;
          school_id: string;
          start_at: string;
          status?: string;
          student_id: string;
          template_id?: string | null;
          travel_after_minutes?: number;
          travel_before_minutes?: number;
        };
        Update: {
          car_id?: string | null;
          created_at?: string;
          decline_reason?: string;
          end_at?: string;
          id?: string;
          instructor_id?: string;
          kind?: string;
          lesson_id?: string | null;
          meet?: string;
          note?: string;
          school_id?: string;
          start_at?: string;
          status?: string;
          student_id?: string;
          template_id?: string | null;
          travel_after_minutes?: number;
          travel_before_minutes?: number;
        };
        Relationships: [
          {
            foreignKeyName: "reservations_car_id_fkey";
            columns: ["car_id"];
            isOneToOne: false;
            referencedRelation: "cars";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reservations_lesson_id_fkey";
            columns: ["lesson_id"];
            isOneToOne: false;
            referencedRelation: "lessons";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reservations_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reservations_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "reservations_template_id_fkey";
            columns: ["template_id"];
            isOneToOne: false;
            referencedRelation: "slot_templates";
            referencedColumns: ["id"];
          },
        ];
      };
      school_enrollments: {
        Row: {
          first_name: string;
          id: string;
          joined_at: string;
          joined_via: string;
          last_name: string;
          left_at: string | null;
          left_reason: string | null;
          school_id: string;
          student_id: string;
        };
        Insert: {
          first_name?: string;
          id?: string;
          joined_at?: string;
          joined_via?: string;
          last_name?: string;
          left_at?: string | null;
          left_reason?: string | null;
          school_id: string;
          student_id: string;
        };
        Update: {
          first_name?: string;
          id?: string;
          joined_at?: string;
          joined_via?: string;
          last_name?: string;
          left_at?: string | null;
          left_reason?: string | null;
          school_id?: string;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "school_enrollments_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "school_enrollments_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      school_invites: {
        Row: {
          accepted_at: string | null;
          access: Json;
          created_at: string;
          email: string;
          expires_at: string;
          id: number;
          invited_by: string | null;
          role: string;
          school_id: string;
          token: string;
        };
        Insert: {
          accepted_at?: string | null;
          access?: Json;
          created_at?: string;
          email: string;
          expires_at?: string;
          id?: never;
          invited_by?: string | null;
          role: string;
          school_id: string;
          token?: string;
        };
        Update: {
          accepted_at?: string | null;
          access?: Json;
          created_at?: string;
          email?: string;
          expires_at?: string;
          id?: never;
          invited_by?: string | null;
          role?: string;
          school_id?: string;
          token?: string;
        };
        Relationships: [
          {
            foreignKeyName: "school_invites_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      school_link_requests: {
        Row: {
          created_at: string;
          expires_at: string;
          id: string;
          requested_by: string | null;
          responded_at: string | null;
          responded_by: string | null;
          school_id: string;
          status: string;
          student_id: string;
        };
        Insert: {
          created_at?: string;
          expires_at?: string;
          id?: string;
          requested_by?: string | null;
          responded_at?: string | null;
          responded_by?: string | null;
          school_id: string;
          status?: string;
          student_id: string;
        };
        Update: {
          created_at?: string;
          expires_at?: string;
          id?: string;
          requested_by?: string | null;
          responded_at?: string | null;
          responded_by?: string | null;
          school_id?: string;
          status?: string;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "school_link_requests_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "school_link_requests_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      school_members: {
        Row: {
          access: Json;
          color: string | null;
          created_at: string;
          hourly_rate: number | null;
          license_expires: string | null;
          role: string;
          school_id: string;
          user_id: string;
        };
        Insert: {
          access?: Json;
          color?: string | null;
          created_at?: string;
          hourly_rate?: number | null;
          license_expires?: string | null;
          role: string;
          school_id: string;
          user_id: string;
        };
        Update: {
          access?: Json;
          color?: string | null;
          created_at?: string;
          hourly_rate?: number | null;
          license_expires?: string | null;
          role?: string;
          school_id?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "school_members_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      schools: {
        Row: {
          cancel_window_hours: number;
          city: string;
          created_at: string;
          created_by: string | null;
          default_lesson_minutes: number;
          id: string;
          name: string;
          package_draw: string;
          phone: string;
          timezone: string;
          who_starts: string;
        };
        Insert: {
          cancel_window_hours?: number;
          city?: string;
          created_at?: string;
          created_by?: string | null;
          default_lesson_minutes?: number;
          id?: string;
          name: string;
          package_draw?: string;
          phone?: string;
          timezone?: string;
          who_starts?: string;
        };
        Update: {
          cancel_window_hours?: number;
          city?: string;
          created_at?: string;
          created_by?: string | null;
          default_lesson_minutes?: number;
          id?: string;
          name?: string;
          package_draw?: string;
          phone?: string;
          timezone?: string;
          who_starts?: string;
        };
        Relationships: [];
      };
      slot_templates: {
        Row: {
          active: boolean;
          car_id: string | null;
          created_at: string;
          days: number[];
          duration_minutes: number;
          id: string;
          instructor_id: string;
          kind: string;
          lot_id: string | null;
          max_advance_days: number;
          meet: string;
          min_notice_hours: number;
          name: string;
          note: string;
          school_id: string;
          travel_after_minutes: number;
          travel_before_minutes: number;
          window_end: string;
          window_start: string;
        };
        Insert: {
          active?: boolean;
          car_id?: string | null;
          created_at?: string;
          days?: number[];
          duration_minutes: number;
          id?: string;
          instructor_id: string;
          kind?: string;
          lot_id?: string | null;
          max_advance_days?: number;
          meet?: string;
          min_notice_hours?: number;
          name: string;
          note?: string;
          school_id: string;
          travel_after_minutes?: number;
          travel_before_minutes?: number;
          window_end?: string;
          window_start?: string;
        };
        Update: {
          active?: boolean;
          car_id?: string | null;
          created_at?: string;
          days?: number[];
          duration_minutes?: number;
          id?: string;
          instructor_id?: string;
          kind?: string;
          lot_id?: string | null;
          max_advance_days?: number;
          meet?: string;
          min_notice_hours?: number;
          name?: string;
          note?: string;
          school_id?: string;
          travel_after_minutes?: number;
          travel_before_minutes?: number;
          window_end?: string;
          window_start?: string;
        };
        Relationships: [
          {
            foreignKeyName: "slot_templates_car_id_fkey";
            columns: ["car_id"];
            isOneToOne: false;
            referencedRelation: "cars";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "slot_templates_lot_id_fkey";
            columns: ["lot_id"];
            isOneToOne: false;
            referencedRelation: "lots";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "slot_templates_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      state_rule_sets: {
        Row: {
          alt_form_name: string;
          alt_form_pdf_url: string;
          alternatives: Json;
          created_at: string;
          daily_cap_minutes: number | null;
          digital_log: string;
          digital_log_apps: string[];
          digital_log_note: string;
          effective_from: string;
          effective_to: string | null;
          field_status: Json;
          form_code: string;
          form_name: string;
          form_number: string;
          form_pdf_status: string;
          form_pdf_url: string;
          form_type: string;
          form_type_detail: string;
          form_url: string;
          gdl_page_url: string;
          handbook_url: string;
          id: string;
          instructor_max_minutes: number | null;
          instructor_multiplier: number;
          jurisdiction_name: string;
          label: string;
          last_checked: string | null;
          lessons_count: boolean;
          link_status: Json;
          log_unit: string;
          night_definition: string;
          night_end: string | null;
          night_minutes: number | null;
          night_rule: string;
          night_start: string | null;
          notarization: string;
          notarization_note: string;
          notes: string;
          other_rules: string;
          parent_guide_url: string;
          pending_change_note: string;
          pending_change_on: string | null;
          requirement_kind: string;
          source_url: string;
          stages: Json;
          state_code: string;
          status: string;
          supervisor_min_age: number | null;
          supervisor_min_years_licensed: number | null;
          supervisor_parent_exempt: boolean;
          supervisor_rule: string;
          total_minutes: number | null;
          verified: boolean;
          verified_on: string | null;
          version: number;
          weather_counts_night: boolean;
          weather_minutes: number | null;
          weekly_cap_minutes: number | null;
        };
        Insert: {
          alt_form_name?: string;
          alt_form_pdf_url?: string;
          alternatives?: Json;
          created_at?: string;
          daily_cap_minutes?: number | null;
          digital_log?: string;
          digital_log_apps?: string[];
          digital_log_note?: string;
          effective_from?: string;
          effective_to?: string | null;
          field_status?: Json;
          form_code?: string;
          form_name?: string;
          form_number?: string;
          form_pdf_status?: string;
          form_pdf_url?: string;
          form_type?: string;
          form_type_detail?: string;
          form_url?: string;
          gdl_page_url?: string;
          handbook_url?: string;
          id?: string;
          instructor_max_minutes?: number | null;
          instructor_multiplier?: number;
          jurisdiction_name?: string;
          label: string;
          last_checked?: string | null;
          lessons_count?: boolean;
          link_status?: Json;
          log_unit?: string;
          night_definition?: string;
          night_end?: string | null;
          night_minutes?: number | null;
          night_rule?: string;
          night_start?: string | null;
          notarization?: string;
          notarization_note?: string;
          notes?: string;
          other_rules?: string;
          parent_guide_url?: string;
          pending_change_note?: string;
          pending_change_on?: string | null;
          requirement_kind?: string;
          source_url?: string;
          stages?: Json;
          state_code: string;
          status?: string;
          supervisor_min_age?: number | null;
          supervisor_min_years_licensed?: number | null;
          supervisor_parent_exempt?: boolean;
          supervisor_rule?: string;
          total_minutes?: number | null;
          verified?: boolean;
          verified_on?: string | null;
          version?: number;
          weather_counts_night?: boolean;
          weather_minutes?: number | null;
          weekly_cap_minutes?: number | null;
        };
        Update: {
          alt_form_name?: string;
          alt_form_pdf_url?: string;
          alternatives?: Json;
          created_at?: string;
          daily_cap_minutes?: number | null;
          digital_log?: string;
          digital_log_apps?: string[];
          digital_log_note?: string;
          effective_from?: string;
          effective_to?: string | null;
          field_status?: Json;
          form_code?: string;
          form_name?: string;
          form_number?: string;
          form_pdf_status?: string;
          form_pdf_url?: string;
          form_type?: string;
          form_type_detail?: string;
          form_url?: string;
          gdl_page_url?: string;
          handbook_url?: string;
          id?: string;
          instructor_max_minutes?: number | null;
          instructor_multiplier?: number;
          jurisdiction_name?: string;
          label?: string;
          last_checked?: string | null;
          lessons_count?: boolean;
          link_status?: Json;
          log_unit?: string;
          night_definition?: string;
          night_end?: string | null;
          night_minutes?: number | null;
          night_rule?: string;
          night_start?: string | null;
          notarization?: string;
          notarization_note?: string;
          notes?: string;
          other_rules?: string;
          parent_guide_url?: string;
          pending_change_note?: string;
          pending_change_on?: string | null;
          requirement_kind?: string;
          source_url?: string;
          stages?: Json;
          state_code?: string;
          status?: string;
          supervisor_min_age?: number | null;
          supervisor_min_years_licensed?: number | null;
          supervisor_parent_exempt?: boolean;
          supervisor_rule?: string;
          total_minutes?: number | null;
          verified?: boolean;
          verified_on?: string | null;
          version?: number;
          weather_counts_night?: boolean;
          weather_minutes?: number | null;
          weekly_cap_minutes?: number | null;
        };
        Relationships: [];
      };
      student_checklist: {
        Row: {
          done: boolean;
          item_key: string;
          label: string;
          source: string;
          student_id: string;
        };
        Insert: {
          done?: boolean;
          item_key: string;
          label: string;
          source?: string;
          student_id: string;
        };
        Update: {
          done?: boolean;
          item_key?: string;
          label?: string;
          source?: string;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "student_checklist_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      student_contacts: {
        Row: {
          created_at: string;
          email: string;
          id: string;
          kind: string;
          name: string;
          phone: string;
          school_id: string;
          student_id: string;
          user_id: string | null;
        };
        Insert: {
          created_at?: string;
          email?: string;
          id?: string;
          kind?: string;
          name?: string;
          phone?: string;
          school_id: string;
          student_id: string;
          user_id?: string | null;
        };
        Update: {
          created_at?: string;
          email?: string;
          id?: string;
          kind?: string;
          name?: string;
          phone?: string;
          school_id?: string;
          student_id?: string;
          user_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "student_contacts_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "student_contacts_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      student_packages: {
        Row: {
          catalog_id: string | null;
          created_at: string;
          hours_left: number;
          hours_total: number;
          id: string;
          school_id: string;
          status: string;
          student_id: string;
        };
        Insert: {
          catalog_id?: string | null;
          created_at?: string;
          hours_left: number;
          hours_total: number;
          id?: string;
          school_id: string;
          status?: string;
          student_id: string;
        };
        Update: {
          catalog_id?: string | null;
          created_at?: string;
          hours_left?: number;
          hours_total?: number;
          id?: string;
          school_id?: string;
          status?: string;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "student_packages_catalog_id_fkey";
            columns: ["catalog_id"];
            isOneToOne: false;
            referencedRelation: "package_catalog";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "student_packages_catalog_id_fkey";
            columns: ["catalog_id"];
            isOneToOne: false;
            referencedRelation: "package_catalog_desk";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "student_packages_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "student_packages_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      student_rule_milestones: {
        Row: {
          created_at: string;
          milestone_key: string;
          reached_on: string;
          set_by: string | null;
          student_id: string;
        };
        Insert: {
          created_at?: string;
          milestone_key: string;
          reached_on: string;
          set_by?: string | null;
          student_id: string;
        };
        Update: {
          created_at?: string;
          milestone_key?: string;
          reached_on?: string;
          set_by?: string | null;
          student_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "student_rule_milestones_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
      students: {
        Row: {
          balance: number;
          birthday: string | null;
          created_at: string;
          first_name: string;
          hour_goal: number;
          id: string;
          instructor_id: string | null;
          join_code: string;
          last_name: string;
          night_goal: number;
          night_hours: number;
          notes: string;
          permit_on: string | null;
          phone: string;
          pickup_address: string;
          practice_hours: number;
          rule_alternative: string | null;
          rule_set_id: string | null;
          school_hours: number;
          school_id: string | null;
          seat: string;
          state_code: string;
          updated_at: string;
          user_id: string | null;
        };
        Insert: {
          balance?: number;
          birthday?: string | null;
          created_at?: string;
          first_name: string;
          hour_goal?: number;
          id?: string;
          instructor_id?: string | null;
          join_code: string;
          last_name?: string;
          night_goal?: number;
          night_hours?: number;
          notes?: string;
          permit_on?: string | null;
          phone?: string;
          pickup_address?: string;
          practice_hours?: number;
          rule_alternative?: string | null;
          rule_set_id?: string | null;
          school_hours?: number;
          school_id?: string | null;
          seat?: string;
          state_code?: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Update: {
          balance?: number;
          birthday?: string | null;
          created_at?: string;
          first_name?: string;
          hour_goal?: number;
          id?: string;
          instructor_id?: string | null;
          join_code?: string;
          last_name?: string;
          night_goal?: number;
          night_hours?: number;
          notes?: string;
          permit_on?: string | null;
          phone?: string;
          pickup_address?: string;
          practice_hours?: number;
          rule_alternative?: string | null;
          rule_set_id?: string | null;
          school_hours?: number;
          school_id?: string | null;
          seat?: string;
          state_code?: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "students_rule_set_id_fkey";
            columns: ["rule_set_id"];
            isOneToOne: false;
            referencedRelation: "state_rule_sets";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "students_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
      supervisors: {
        Row: {
          active: boolean;
          birth_date: string | null;
          can_sign: boolean;
          created_at: string;
          created_by: string | null;
          id: string;
          licensed_since: string | null;
          meets_requirements: boolean;
          name: string;
          relationship: string;
          school_id: string | null;
          student_id: string;
          updated_at: string;
          user_id: string | null;
        };
        Insert: {
          active?: boolean;
          birth_date?: string | null;
          can_sign?: boolean;
          created_at?: string;
          created_by?: string | null;
          id?: string;
          licensed_since?: string | null;
          meets_requirements?: boolean;
          name: string;
          relationship?: string;
          school_id?: string | null;
          student_id: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Update: {
          active?: boolean;
          birth_date?: string | null;
          can_sign?: boolean;
          created_at?: string;
          created_by?: string | null;
          id?: string;
          licensed_since?: string | null;
          meets_requirements?: boolean;
          name?: string;
          relationship?: string;
          school_id?: string | null;
          student_id?: string;
          updated_at?: string;
          user_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "supervisors_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "supervisors_student_id_fkey";
            columns: ["student_id"];
            isOneToOne: false;
            referencedRelation: "students";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      package_catalog_desk: {
        Row: {
          active: boolean | null;
          hours: number | null;
          id: string | null;
          kind: string | null;
          name: string | null;
          price: number | null;
          school_id: string | null;
        };
        Insert: {
          active?: boolean | null;
          hours?: number | null;
          id?: string | null;
          kind?: string | null;
          name?: string | null;
          price?: never;
          school_id?: string | null;
        };
        Update: {
          active?: boolean | null;
          hours?: number | null;
          id?: string | null;
          kind?: string | null;
          name?: string | null;
          price?: never;
          school_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "package_catalog_school_id_fkey";
            columns: ["school_id"];
            isOneToOne: false;
            referencedRelation: "schools";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Functions: {
      accept_my_invites: { Args: never; Returns: number };
      accept_reservation: {
        Args: { p_reservation_id: string };
        Returns: string;
      };
      accept_school_invite: { Args: { p_token: string }; Returns: string };
      add_block: {
        Args: {
          p_end: string;
          p_instructor_id: string;
          p_name?: string;
          p_school_id: string;
          p_start: string;
        };
        Returns: string;
      };
      add_car: {
        Args: {
          p_assigned_user_id?: string;
          p_color?: string;
          p_model?: string;
          p_name: string;
          p_odo_miles?: number;
          p_plate?: string;
          p_school_id: string;
        };
        Returns: string;
      };
      add_lot: {
        Args: { p_is_default?: boolean; p_name: string; p_school_id: string };
        Returns: string;
      };
      add_slot_template: {
        Args: {
          p_car_id?: string;
          p_days?: number[];
          p_duration_minutes?: number;
          p_instructor_id: string;
          p_kind?: string;
          p_max_advance_days?: number;
          p_meet?: string;
          p_min_notice_hours?: number;
          p_name: string;
          p_note?: string;
          p_school_id: string;
          p_travel_after_minutes?: number;
          p_travel_before_minutes?: number;
          p_window_end?: string;
          p_window_start?: string;
        };
        Returns: string;
      };
      add_student: {
        Args: {
          p_birthday?: string;
          p_first_name: string;
          p_instructor_id?: string;
          p_last_name?: string;
          p_package_hours?: number;
          p_parent_email?: string;
          p_parent_name?: string;
          p_school_id: string;
        };
        Returns: string;
      };
      assign_student_package: {
        Args: {
          p_catalog_id: string;
          p_school_id: string;
          p_student_id: string;
        };
        Returns: string;
      };
      book_lesson: {
        Args: {
          p_car_id?: string;
          p_end: string;
          p_instructor_id: string;
          p_kind?: string;
          p_meet?: string;
          p_notes?: string;
          p_school_id: string;
          p_start: string;
          p_student_id: string;
          p_template_id?: string;
          p_travel_after_minutes?: number;
          p_travel_before_minutes?: number;
        };
        Returns: string;
      };
      cancel_student_link_request: {
        Args: { p_request_id: string };
        Returns: undefined;
      };
      claim_student_profile: { Args: { p_join_code: string }; Returns: Json };
      compute_instructor_pay: {
        Args: {
          p_period_end: string;
          p_period_start: string;
          p_school_id: string;
        };
        Returns: {
          amount: number;
          hours: number;
          instructor_id: string;
          rate: number;
        }[];
      };
      create_family_invite: {
        Args: {
          p_email?: string;
          p_max_uses?: number;
          p_relationship?: string;
          p_student_id: string;
        };
        Returns: Json;
      };
      create_independent_student: {
        Args: {
          p_birthday?: string;
          p_first_name: string;
          p_for?: string;
          p_last_name?: string;
          p_relationship?: string;
          p_state_code?: string;
        };
        Returns: Json;
      };
      create_school: {
        Args: { p_city?: string; p_name: string };
        Returns: string;
      };
      decline_reservation: {
        Args: { p_reason?: string; p_reservation_id: string };
        Returns: undefined;
      };
      invite_to_school: {
        Args: {
          p_access?: Json;
          p_email: string;
          p_role?: string;
          p_school_id: string;
        };
        Returns: string;
      };
      join_school_with_code: {
        Args: { p_join_code: string; p_student_id: string };
        Returns: Json;
      };
      leave_school: { Args: { p_student_id: string }; Returns: Json };
      list_drives: {
        Args: {
          p_before_id?: string;
          p_before_started_at?: string;
          p_limit?: number;
          p_student_id: string;
        };
        Returns: {
          conditions: string[];
          distance_miles: number;
          duration_minutes: number;
          end_label: string;
          ended_at: string;
          has_route: boolean;
          id: string;
          kind: string;
          local_date: string;
          locked_at: string;
          night_minutes: number;
          notes: string;
          skills: string[];
          source: string;
          start_label: string;
          started_at: string;
          status: string;
          student_id: string;
          supervisor_id: string;
          supervisor_name: string;
          tz: string;
          weather_minutes: number;
        }[];
      };
      mark_lesson: {
        Args: { p_lesson_id: string; p_status: string };
        Returns: undefined;
      };
      member_hourly_rate: {
        Args: { p_school_id: string; p_user_id: string };
        Returns: number;
      };
      my_rule_resources: { Args: { p_student_id: string }; Returns: Json };
      my_school_requests: {
        Args: never;
        Returns: {
          created_at: string;
          currently_at_school: string;
          expires_at: string;
          request_id: string;
          school_city: string;
          school_id: string;
          school_name: string;
          student_first_name: string;
          student_id: string;
        }[];
      };
      my_students: {
        Args: never;
        Returns: {
          can_sign: boolean;
          first_name: string;
          last_name: string;
          relation: string;
          school_id: string;
          school_name: string;
          state_code: string;
          student_id: string;
        }[];
      };
      pending_signoffs: {
        Args: { p_limit?: number };
        Returns: {
          distance_miles: number;
          drive_id: string;
          duration_minutes: number;
          first_name: string;
          night_minutes: number;
          started_at: string;
          student_id: string;
          supervisor_name: string;
        }[];
      };
      qbo_begin_connect: { Args: { p_school_id: string }; Returns: string };
      qbo_disconnect: { Args: { p_school_id: string }; Returns: undefined };
      qbo_sync_status: {
        Args: { p_school_id: string };
        Returns: {
          company_name: string;
          dead: number;
          failed: number;
          last_error: string;
          last_sync_at: string;
          queued: number;
          refresh_expires_at: string;
          status: string;
        }[];
      };
      reassign_lesson: {
        Args: {
          p_car_id?: string;
          p_instructor_id: string;
          p_lesson_id: string;
        };
        Returns: undefined;
      };
      record_invoice_payment: {
        Args: {
          p_amount: number;
          p_customer_id: string;
          p_invoice_id: string;
          p_method?: string;
          p_received_on?: string;
          p_reference?: string;
          p_school_id: string;
          p_student_id: string;
        };
        Returns: string;
      };
      redeem_family_invite: { Args: { p_code: string }; Returns: Json };
      register_web_push: {
        Args: {
          p_auth: string;
          p_endpoint: string;
          p_p256dh: string;
          p_user_agent?: string;
        };
        Returns: string;
      };
      reject_drive: {
        Args: { p_drive_id: string; p_reason?: string };
        Returns: undefined;
      };
      release_student: { Args: { p_student_id: string }; Returns: Json };
      request_slot: {
        Args: {
          p_car_id?: string;
          p_end: string;
          p_instructor_id: string;
          p_kind?: string;
          p_meet?: string;
          p_note?: string;
          p_school_id: string;
          p_start: string;
          p_student_id: string;
          p_template_id?: string;
          p_travel_after_minutes?: number;
          p_travel_before_minutes?: number;
        };
        Returns: string;
      };
      request_student_link: {
        Args: { p_school_id: string; p_student_code: string };
        Returns: Json;
      };
      respond_school_request: {
        Args: { p_accept: boolean; p_request_id: string };
        Returns: Json;
      };
      revoke_family_invite: {
        Args: { p_invite_id: string };
        Returns: undefined;
      };
      revoke_family_link: { Args: { p_link_id: string }; Returns: undefined };
      revoke_invite: { Args: { p_invite_id: number }; Returns: undefined };
      school_schedule: {
        Args: { p_from: string; p_school_id: string; p_to: string };
        Returns: {
          cancelled_at: string | null;
          car_id: string | null;
          created_at: string;
          created_by: string | null;
          drive_id: string | null;
          end_at: string;
          hours_drawn: number;
          id: string;
          instructor_id: string;
          kind: string;
          lot_id: string | null;
          meet: string;
          name: string;
          notes: string;
          package_id: string | null;
          pickup: string;
          school_id: string;
          start_at: string;
          status: string;
          student_id: string | null;
          template_id: string | null;
          topic: string;
          travel_after_minutes: number;
          travel_before_minutes: number;
          updated_at: string;
        }[];
        SetofOptions: {
          from: "*";
          to: "lessons";
          isOneToOne: false;
          isSetofReturn: true;
        };
      };
      school_students_progress: {
        Args: {
          p_after_first?: string;
          p_after_id?: string;
          p_after_last?: string;
          p_limit?: number;
          p_school_id: string;
        };
        Returns: {
          first_name: string;
          hour_goal: number;
          instructor_id: string;
          last_drive_at: string;
          last_name: string;
          night_goal: number;
          night_hours: number;
          pending_drives: number;
          practice_hours: number;
          school_hours: number;
          seat: string;
          student_id: string;
        }[];
      };
      set_account_type: { Args: { p_type: string }; Returns: undefined };
      set_rule_alternative: {
        Args: { p_key: string; p_student_id: string };
        Returns: Json;
      };
      set_rule_milestone: {
        Args: { p_key: string; p_reached_on: string; p_student_id: string };
        Returns: Json;
      };
      set_student_checklist_item: {
        Args: { p_done: boolean; p_item_key: string; p_student_id: string };
        Returns: undefined;
      };
      sign_drive: {
        Args: {
          p_device?: Json;
          p_drive_id: string;
          p_initials?: string;
          p_method: string;
          p_supervisor_id?: string;
        };
        Returns: Json;
      };
      state_resources: {
        Args: { p_permit_on?: string; p_state_code: string };
        Returns: Json;
      };
      student_hours_by_day: {
        Args: {
          p_from?: string;
          p_include_pending?: boolean;
          p_student_id: string;
          p_to?: string;
        };
        Returns: {
          capped: boolean;
          credited_minutes: number;
          drives: number;
          local_date: string;
          miles: number;
          night_credited_minutes: number;
          raw_minutes: number;
          raw_night_minutes: number;
          raw_weather_minutes: number;
          weather_credited_minutes: number;
          week_start: string;
        }[];
      };
      student_hours_summary: {
        Args: { p_student_id: string };
        Returns: {
          credited_minutes: number;
          daily_cap_minutes: number;
          day_credited_minutes: number;
          form_code: string;
          lesson_minutes: number;
          night_credited_minutes: number;
          pending_drives: number;
          pending_extra_minutes: number;
          raw_minutes: number;
          remaining_minutes: number;
          remaining_night_minutes: number;
          required_minutes: number;
          required_night_minutes: number;
          requirement_met: boolean;
          rule_label: string;
          rule_set_id: string;
          rule_verified: boolean;
          school_goal_minutes: number;
          signed_miles: number;
          state_code: string;
          student_id: string;
        }[];
      };
      student_rule_progress: { Args: { p_student_id: string }; Returns: Json };
      svc_claim_notifications: {
        Args: { p_limit?: number };
        Returns: {
          attempts: number;
          id: string;
          idempotency_key: string;
          kind: string;
          payload: Json;
          to_email: string;
        }[];
      };
      svc_expire_exports: {
        Args: never;
        Returns: {
          storage_path: string;
        }[];
      };
      svc_finish_notification: {
        Args: { p_error?: string; p_id: string; p_ok: boolean };
        Returns: undefined;
      };
      svc_housekeeping: { Args: never; Returns: Json };
      svc_qbo_apply_entity: {
        Args: { p_entity: string; p_obj: Json; p_school_id: string };
        Returns: string;
      };
      svc_qbo_claim_jobs: {
        Args: { p_limit?: number };
        Returns: {
          attempts: number;
          direction: string;
          entity: string;
          id: string;
          local_id: string;
          payload: Json;
          qbo_id: string;
          school_id: string;
        }[];
      };
      svc_qbo_consume_state: {
        Args: { p_state: string };
        Returns: {
          school_id: string;
          user_id: string;
        }[];
      };
      svc_qbo_due_for_refresh: {
        Args: { p_within_minutes?: number };
        Returns: {
          school_id: string;
        }[];
      };
      svc_qbo_finish_job: {
        Args: {
          p_error?: string;
          p_job_id: string;
          p_ok: boolean;
          p_qbo_id?: string;
          p_qbo_updated_at?: string;
          p_sync_token?: string;
        };
        Returns: undefined;
      };
      svc_qbo_get_tokens: {
        Args: { p_school_id: string };
        Returns: {
          access_expires_at: string;
          access_token: string;
          environment: string;
          realm_id: string;
          refresh_token: string;
        }[];
      };
      svc_qbo_mark_deleted: {
        Args: { p_entity: string; p_qbo_id: string; p_school_id: string };
        Returns: undefined;
      };
      svc_qbo_mark_error: {
        Args: { p_error: string; p_needs_reauth?: boolean; p_school_id: string };
        Returns: undefined;
      };
      svc_qbo_record_events: { Args: { p_events: Json }; Returns: number };
      svc_qbo_store_tokens: {
        Args: {
          p_access_expires_in: number;
          p_access_token: string;
          p_company_name?: string;
          p_environment?: string;
          p_realm_id: string;
          p_refresh_expires_in: number;
          p_refresh_token: string;
          p_school_id: string;
          p_user_id?: string;
        };
        Returns: undefined;
      };
      update_car_compliance: {
        Args: { p_car_id: string; p_patch: Json; p_school_id: string };
        Returns: undefined;
      };
      update_lot_coords: {
        Args: {
          p_lat: number;
          p_lng: number;
          p_lot_id: string;
          p_school_id: string;
        };
        Returns: undefined;
      };
      update_my_student: {
        Args: {
          p_birthday?: string;
          p_first_name?: string;
          p_last_name?: string;
          p_permit_on?: string;
          p_state_code?: string;
          p_student_id: string;
        };
        Returns: undefined;
      };
      update_school: {
        Args: {
          p_cancel_window_hours?: number;
          p_city?: string;
          p_default_lesson_minutes?: number;
          p_name?: string;
          p_phone?: string;
          p_school_id: string;
          p_timezone?: string;
          p_who_starts?: string;
        };
        Returns: undefined;
      };
      upsert_student_checklist_item: {
        Args: {
          p_done?: boolean;
          p_item_key: string;
          p_label: string;
          p_student_id: string;
        };
        Returns: undefined;
      };
      void_drive: {
        Args: { p_drive_id: string; p_reason: string };
        Returns: undefined;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    keyof (DefaultSchema["Tables"] & DefaultSchema["Views"]) | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  public: {
    Enums: {},
  },
} as const;
