export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.4"
  }
  public: {
    Tables: {
      audit_log: {
        Row: {
          action: string
          changes: Json | null
          created_at: string | null
          entity_id: string
          entity_type: string
          id: string
          user_id: string | null
        }
        Insert: {
          action: string
          changes?: Json | null
          created_at?: string | null
          entity_id: string
          entity_type: string
          id?: string
          user_id?: string | null
        }
        Update: {
          action?: string
          changes?: Json | null
          created_at?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      availability_schedules: {
        Row: {
          created_at: string | null
          day_of_week: number
          end_time: string
          id: string
          inspector_id: string
          is_available: boolean | null
          start_time: string
        }
        Insert: {
          created_at?: string | null
          day_of_week: number
          end_time: string
          id?: string
          inspector_id: string
          is_available?: boolean | null
          start_time: string
        }
        Update: {
          created_at?: string | null
          day_of_week?: number
          end_time?: string
          id?: string
          inspector_id?: string
          is_available?: boolean | null
          start_time?: string
        }
        Relationships: [
          {
            foreignKeyName: "availability_schedules_inspector_id_fkey"
            columns: ["inspector_id"]
            isOneToOne: false
            referencedRelation: "inspectors"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          address: string | null
          city: string | null
          contact_email: string | null
          contact_phone: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          id: string
          is_active: boolean | null
          logo_url: string | null
          name: string
          slug: string
          state: string | null
          subscription_tier: string | null
          updated_at: string | null
          updated_by: string | null
          zip: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          is_active?: boolean | null
          logo_url?: string | null
          name: string
          slug: string
          state?: string | null
          subscription_tier?: string | null
          updated_at?: string | null
          updated_by?: string | null
          zip?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          is_active?: boolean | null
          logo_url?: string | null
          name?: string
          slug?: string
          state?: string | null
          subscription_tier?: string | null
          updated_at?: string | null
          updated_by?: string | null
          zip?: string | null
        }
        Relationships: []
      }
      device_tokens: {
        Row: {
          app_version: string | null
          created_at: string
          id: string
          last_seen: string
          platform: string
          token: string
          user_id: string
        }
        Insert: {
          app_version?: string | null
          created_at?: string
          id?: string
          last_seen?: string
          platform?: string
          token: string
          user_id: string
        }
        Update: {
          app_version?: string | null
          created_at?: string
          id?: string
          last_seen?: string
          platform?: string
          token?: string
          user_id?: string
        }
        Relationships: []
      }
      dispatch_assignments: {
        Row: {
          accepted_at: string | null
          assigned_by: string | null
          assignment_type: string | null
          completed_at: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          dispatch_score: number | null
          distance_miles: number | null
          id: string
          inspection_request_id: string
          inspector_id: string | null
          notes: string | null
          scheduled_date: string | null
          scheduled_time: string | null
          status: string | null
          updated_at: string | null
          updated_by: string | null
        }
        Insert: {
          accepted_at?: string | null
          assigned_by?: string | null
          assignment_type?: string | null
          completed_at?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          dispatch_score?: number | null
          distance_miles?: number | null
          id?: string
          inspection_request_id: string
          inspector_id?: string | null
          notes?: string | null
          scheduled_date?: string | null
          scheduled_time?: string | null
          status?: string | null
          updated_at?: string | null
          updated_by?: string | null
        }
        Update: {
          accepted_at?: string | null
          assigned_by?: string | null
          assignment_type?: string | null
          completed_at?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          dispatch_score?: number | null
          distance_miles?: number | null
          id?: string
          inspection_request_id?: string
          inspector_id?: string | null
          notes?: string | null
          scheduled_date?: string | null
          scheduled_time?: string | null
          status?: string | null
          updated_at?: string | null
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "dispatch_assignments_inspection_request_id_fkey"
            columns: ["inspection_request_id"]
            isOneToOne: false
            referencedRelation: "inspection_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dispatch_assignments_inspector_id_fkey"
            columns: ["inspector_id"]
            isOneToOne: false
            referencedRelation: "inspectors"
            referencedColumns: ["id"]
          },
        ]
      }
      earnings_settings: {
        Row: {
          default_job_fee: number
          default_mileage_fee: number
          estimated_tax_rate: number
          federal_tax_rate: number
          filing_status: string
          id: string
          mileage_rate: number
          organization_id: string
          self_employment_tax_rate: number
          state_code: string | null
          state_tax_rate: number
          updated_at: string
          user_id: string
        }
        Insert: {
          default_job_fee?: number
          default_mileage_fee?: number
          estimated_tax_rate?: number
          federal_tax_rate?: number
          filing_status?: string
          id?: string
          mileage_rate?: number
          organization_id: string
          self_employment_tax_rate?: number
          state_code?: string | null
          state_tax_rate?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          default_job_fee?: number
          default_mileage_fee?: number
          estimated_tax_rate?: number
          federal_tax_rate?: number
          filing_status?: string
          id?: string
          mileage_rate?: number
          organization_id?: string
          self_employment_tax_rate?: number
          state_code?: string | null
          state_tax_rate?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "earnings_settings_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      inspection_requests: {
        Row: {
          client_name: string | null
          company_id: string | null
          company_name: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          id: string
          inspection_location: string | null
          inspection_type: string | null
          inspector_id: string | null
          mileage: string | null
          notes: string | null
          overall_score: number | null
          priority: string | null
          requested_date: string | null
          status: string | null
          template_id: string | null
          template_name: string | null
          updated_at: string | null
          updated_by: string | null
          vehicle_condition_rating: string | null
          vehicle_id: string | null
          vehicle_make: string | null
          vehicle_model: string | null
          vehicle_year: string | null
          vin: string | null
        }
        Insert: {
          client_name?: string | null
          company_id?: string | null
          company_name?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          inspection_location?: string | null
          inspection_type?: string | null
          inspector_id?: string | null
          mileage?: string | null
          notes?: string | null
          overall_score?: number | null
          priority?: string | null
          requested_date?: string | null
          status?: string | null
          template_id?: string | null
          template_name?: string | null
          updated_at?: string | null
          updated_by?: string | null
          vehicle_condition_rating?: string | null
          vehicle_id?: string | null
          vehicle_make?: string | null
          vehicle_model?: string | null
          vehicle_year?: string | null
          vin?: string | null
        }
        Update: {
          client_name?: string | null
          company_id?: string | null
          company_name?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          inspection_location?: string | null
          inspection_type?: string | null
          inspector_id?: string | null
          mileage?: string | null
          notes?: string | null
          overall_score?: number | null
          priority?: string | null
          requested_date?: string | null
          status?: string | null
          template_id?: string | null
          template_name?: string | null
          updated_at?: string | null
          updated_by?: string | null
          vehicle_condition_rating?: string | null
          vehicle_id?: string | null
          vehicle_make?: string | null
          vehicle_model?: string | null
          vehicle_year?: string | null
          vin?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inspection_requests_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspection_requests_inspector_id_fkey"
            columns: ["inspector_id"]
            isOneToOne: false
            referencedRelation: "inspectors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspection_requests_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "inspection_templates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspection_requests_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      inspection_scores: {
        Row: {
          created_at: string | null
          id: string
          inspection_request_id: string
          overall_score: number | null
          section_scores: Json | null
          vehicle_condition_rating: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          inspection_request_id: string
          overall_score?: number | null
          section_scores?: Json | null
          vehicle_condition_rating?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          inspection_request_id?: string
          overall_score?: number | null
          section_scores?: Json | null
          vehicle_condition_rating?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inspection_scores_inspection_request_id_fkey"
            columns: ["inspection_request_id"]
            isOneToOne: false
            referencedRelation: "inspection_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      inspection_templates: {
        Row: {
          company_id: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          description: string | null
          id: string
          inspection_type: string | null
          is_marketplace: boolean | null
          is_published: boolean | null
          name: string
          source_provider: string | null
          updated_at: string | null
          updated_by: string | null
          version: number | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          id?: string
          inspection_type?: string | null
          is_marketplace?: boolean | null
          is_published?: boolean | null
          name: string
          source_provider?: string | null
          updated_at?: string | null
          updated_by?: string | null
          version?: number | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          id?: string
          inspection_type?: string | null
          is_marketplace?: boolean | null
          is_published?: boolean | null
          name?: string
          source_provider?: string | null
          updated_at?: string | null
          updated_by?: string | null
          version?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "inspection_templates_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      inspector_blocked_dates: {
        Row: {
          blocked_date: string
          created_at: string | null
          id: string
          inspector_id: string
          reason: string | null
        }
        Insert: {
          blocked_date: string
          created_at?: string | null
          id?: string
          inspector_id: string
          reason?: string | null
        }
        Update: {
          blocked_date?: string
          created_at?: string | null
          id?: string
          inspector_id?: string
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inspector_blocked_dates_inspector_id_fkey"
            columns: ["inspector_id"]
            isOneToOne: false
            referencedRelation: "inspectors"
            referencedColumns: ["id"]
          },
        ]
      }
      inspector_ratings: {
        Row: {
          comment: string | null
          created_at: string | null
          id: string
          inspection_request_id: string | null
          inspector_id: string
          rated_by: string | null
          score: number | null
        }
        Insert: {
          comment?: string | null
          created_at?: string | null
          id?: string
          inspection_request_id?: string | null
          inspector_id: string
          rated_by?: string | null
          score?: number | null
        }
        Update: {
          comment?: string | null
          created_at?: string | null
          id?: string
          inspection_request_id?: string | null
          inspector_id?: string
          rated_by?: string | null
          score?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "inspector_ratings_inspection_request_id_fkey"
            columns: ["inspection_request_id"]
            isOneToOne: false
            referencedRelation: "inspection_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspector_ratings_inspector_id_fkey"
            columns: ["inspector_id"]
            isOneToOne: false
            referencedRelation: "inspectors"
            referencedColumns: ["id"]
          },
        ]
      }
      inspector_vehicles: {
        Row: {
          created_at: string
          id: string
          is_archived: boolean
          is_default: boolean
          license_plate: string | null
          make: string | null
          model: string | null
          nickname: string
          organization_id: string
          updated_at: string
          user_id: string
          year: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_archived?: boolean
          is_default?: boolean
          license_plate?: string | null
          make?: string | null
          model?: string | null
          nickname: string
          organization_id: string
          updated_at?: string
          user_id: string
          year?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_archived?: boolean
          is_default?: boolean
          license_plate?: string | null
          make?: string | null
          model?: string | null
          nickname?: string
          organization_id?: string
          updated_at?: string
          user_id?: string
          year?: string | null
        }
        Relationships: []
      }
      inspectors: {
        Row: {
          avatar_url: string | null
          certifications: string[] | null
          company_id: string | null
          completed_jobs: number | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          email: string | null
          hourly_rate: number | null
          id: string
          name: string
          phone: string | null
          rating: number | null
          status: string | null
          updated_at: string | null
          updated_by: string | null
          user_id: string | null
        }
        Insert: {
          avatar_url?: string | null
          certifications?: string[] | null
          company_id?: string | null
          completed_jobs?: number | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          email?: string | null
          hourly_rate?: number | null
          id?: string
          name: string
          phone?: string | null
          rating?: number | null
          status?: string | null
          updated_at?: string | null
          updated_by?: string | null
          user_id?: string | null
        }
        Update: {
          avatar_url?: string | null
          certifications?: string[] | null
          company_id?: string | null
          completed_jobs?: number | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          email?: string | null
          hourly_rate?: number | null
          id?: string
          name?: string
          phone?: string | null
          rating?: number | null
          status?: string | null
          updated_at?: string | null
          updated_by?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inspectors_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      jobs: {
        Row: {
          actual_end_time: string | null
          actual_start_time: string | null
          assigned_to: string | null
          created_at: string
          created_by: string | null
          customer_name: string | null
          deleted_at: string | null
          estimated_duration_minutes: number | null
          fee_override: number | null
          id: string
          inspection_request_id: string | null
          location: string | null
          mileage_fee: number | null
          notes: string | null
          organization_id: string
          scheduled_at: string | null
          status: string
          title: string
          updated_at: string
          updated_by: string | null
          vehicle_id: string | null
        }
        Insert: {
          actual_end_time?: string | null
          actual_start_time?: string | null
          assigned_to?: string | null
          created_at?: string
          created_by?: string | null
          customer_name?: string | null
          deleted_at?: string | null
          estimated_duration_minutes?: number | null
          fee_override?: number | null
          id?: string
          inspection_request_id?: string | null
          location?: string | null
          mileage_fee?: number | null
          notes?: string | null
          organization_id: string
          scheduled_at?: string | null
          status?: string
          title: string
          updated_at?: string
          updated_by?: string | null
          vehicle_id?: string | null
        }
        Update: {
          actual_end_time?: string | null
          actual_start_time?: string | null
          assigned_to?: string | null
          created_at?: string
          created_by?: string | null
          customer_name?: string | null
          deleted_at?: string | null
          estimated_duration_minutes?: number | null
          fee_override?: number | null
          id?: string
          inspection_request_id?: string | null
          location?: string | null
          mileage_fee?: number | null
          notes?: string | null
          organization_id?: string
          scheduled_at?: string | null
          status?: string
          title?: string
          updated_at?: string
          updated_by?: string | null
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "jobs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_users: {
        Row: {
          created_at: string
          id: string
          is_default: boolean
          organization_id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_default?: boolean
          organization_id: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_default?: boolean
          organization_id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_users_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          name: string
          owner_id: string | null
          slug: string | null
          type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          name: string
          owner_id?: string | null
          slug?: string | null
          type?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          name?: string
          owner_id?: string | null
          slug?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: []
      }
      parsed_documents: {
        Row: {
          created_at: string | null
          id: string
          inspection_request_id: string | null
          original_text: string | null
          parsed_data: Json | null
          source_file_name: string | null
          source_file_path: string | null
          source_type: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          inspection_request_id?: string | null
          original_text?: string | null
          parsed_data?: Json | null
          source_file_name?: string | null
          source_file_path?: string | null
          source_type: string
        }
        Update: {
          created_at?: string | null
          id?: string
          inspection_request_id?: string | null
          original_text?: string | null
          parsed_data?: Json | null
          source_file_name?: string | null
          source_file_path?: string | null
          source_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "parsed_documents_inspection_request_id_fkey"
            columns: ["inspection_request_id"]
            isOneToOne: false
            referencedRelation: "inspection_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          calendar_feed_token: string | null
          company_id: string | null
          created_at: string | null
          full_name: string | null
          id: string
          phone: string | null
          updated_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          calendar_feed_token?: string | null
          company_id?: string | null
          created_at?: string | null
          full_name?: string | null
          id: string
          phone?: string | null
          updated_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          calendar_feed_token?: string | null
          company_id?: string | null
          created_at?: string | null
          full_name?: string | null
          id?: string
          phone?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      quarterly_tax_overrides: {
        Row: {
          created_at: string
          deductions_override: number | null
          estimated_tax_override: number | null
          id: string
          income_override: number | null
          is_paid: boolean
          notes: string | null
          organization_id: string
          paid_amount: number | null
          paid_at: string | null
          quarter: number
          updated_at: string
          user_id: string
          year: number
        }
        Insert: {
          created_at?: string
          deductions_override?: number | null
          estimated_tax_override?: number | null
          id?: string
          income_override?: number | null
          is_paid?: boolean
          notes?: string | null
          organization_id: string
          paid_amount?: number | null
          paid_at?: string | null
          quarter: number
          updated_at?: string
          user_id: string
          year: number
        }
        Update: {
          created_at?: string
          deductions_override?: number | null
          estimated_tax_override?: number | null
          id?: string
          income_override?: number | null
          is_paid?: boolean
          notes?: string | null
          organization_id?: string
          paid_amount?: number | null
          paid_at?: string | null
          quarter?: number
          updated_at?: string
          user_id?: string
          year?: number
        }
        Relationships: []
      }
      repair_estimates: {
        Row: {
          created_at: string | null
          estimated_cost: number | null
          id: string
          inspection_request_id: string
          item_label: string
          labor_hours: number | null
          labor_rate: number | null
          notes: string | null
          parts_cost: number | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          estimated_cost?: number | null
          id?: string
          inspection_request_id: string
          item_label: string
          labor_hours?: number | null
          labor_rate?: number | null
          notes?: string | null
          parts_cost?: number | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          estimated_cost?: number | null
          id?: string
          inspection_request_id?: string
          item_label?: string
          labor_hours?: number | null
          labor_rate?: number | null
          notes?: string | null
          parts_cost?: number | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "repair_estimates_inspection_request_id_fkey"
            columns: ["inspection_request_id"]
            isOneToOne: false
            referencedRelation: "inspection_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      template_checklist_items: {
        Row: {
          created_at: string | null
          id: string
          input_type: string | null
          is_required: boolean | null
          label: string
          options: Json | null
          requires_photo: boolean | null
          requires_video: boolean | null
          section_id: string
          sort_order: number | null
          weight: number | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          input_type?: string | null
          is_required?: boolean | null
          label: string
          options?: Json | null
          requires_photo?: boolean | null
          requires_video?: boolean | null
          section_id: string
          sort_order?: number | null
          weight?: number | null
        }
        Update: {
          created_at?: string | null
          id?: string
          input_type?: string | null
          is_required?: boolean | null
          label?: string
          options?: Json | null
          requires_photo?: boolean | null
          requires_video?: boolean | null
          section_id?: string
          sort_order?: number | null
          weight?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "template_checklist_items_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "template_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      template_required_photos: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          label: string
          sort_order: number | null
          template_id: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          label: string
          sort_order?: number | null
          template_id: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          label?: string
          sort_order?: number | null
          template_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "template_required_photos_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "inspection_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      template_sections: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          name: string
          sort_order: number | null
          template_id: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          name: string
          sort_order?: number | null
          template_id: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          name?: string
          sort_order?: number | null
          template_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "template_sections_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "inspection_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      template_special_instructions: {
        Row: {
          created_at: string | null
          id: string
          instruction: string
          sort_order: number | null
          template_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          instruction: string
          sort_order?: number | null
          template_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          instruction?: string
          sort_order?: number | null
          template_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "template_special_instructions_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "inspection_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      template_subscriptions: {
        Row: {
          company_id: string
          id: string
          is_active: boolean | null
          subscribed_at: string | null
          template_id: string
        }
        Insert: {
          company_id: string
          id?: string
          is_active?: boolean | null
          subscribed_at?: string | null
          template_id: string
        }
        Update: {
          company_id?: string
          id?: string
          is_active?: boolean | null
          subscribed_at?: string | null
          template_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "template_subscriptions_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "template_subscriptions_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "inspection_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      territories: {
        Row: {
          city: string | null
          created_at: string | null
          id: string
          inspector_id: string
          is_active: boolean | null
          latitude: number | null
          longitude: number | null
          name: string
          radius_miles: number | null
          state: string | null
          zip_codes: string[] | null
        }
        Insert: {
          city?: string | null
          created_at?: string | null
          id?: string
          inspector_id: string
          is_active?: boolean | null
          latitude?: number | null
          longitude?: number | null
          name: string
          radius_miles?: number | null
          state?: string | null
          zip_codes?: string[] | null
        }
        Update: {
          city?: string | null
          created_at?: string | null
          id?: string
          inspector_id?: string
          is_active?: boolean | null
          latitude?: number | null
          longitude?: number | null
          name?: string
          radius_miles?: number | null
          state?: string | null
          zip_codes?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "territories_inspector_id_fkey"
            columns: ["inspector_id"]
            isOneToOne: false
            referencedRelation: "inspectors"
            referencedColumns: ["id"]
          },
        ]
      }
      trip_location_points: {
        Row: {
          accuracy: number | null
          created_at: string
          distance_from_previous_miles: number | null
          heading: number | null
          id: string
          latitude: number
          longitude: number
          organization_id: string
          recorded_at: string
          speed: number | null
          trip_id: string
          user_id: string
        }
        Insert: {
          accuracy?: number | null
          created_at?: string
          distance_from_previous_miles?: number | null
          heading?: number | null
          id?: string
          latitude: number
          longitude: number
          organization_id: string
          recorded_at?: string
          speed?: number | null
          trip_id: string
          user_id: string
        }
        Update: {
          accuracy?: number | null
          created_at?: string
          distance_from_previous_miles?: number | null
          heading?: number | null
          id?: string
          latitude?: number
          longitude?: number
          organization_id?: string
          recorded_at?: string
          speed?: number | null
          trip_id?: string
          user_id?: string
        }
        Relationships: []
      }
      trip_stops: {
        Row: {
          address: string | null
          arrived_at: string | null
          completed_at: string | null
          created_at: string
          departed_at: string | null
          id: string
          job_id: string | null
          label: string | null
          latitude: number | null
          longitude: number | null
          miles_from_previous: number | null
          notes: string | null
          sort_order: number
          status: string
          trip_id: string
        }
        Insert: {
          address?: string | null
          arrived_at?: string | null
          completed_at?: string | null
          created_at?: string
          departed_at?: string | null
          id?: string
          job_id?: string | null
          label?: string | null
          latitude?: number | null
          longitude?: number | null
          miles_from_previous?: number | null
          notes?: string | null
          sort_order?: number
          status?: string
          trip_id: string
        }
        Update: {
          address?: string | null
          arrived_at?: string | null
          completed_at?: string | null
          created_at?: string
          departed_at?: string | null
          id?: string
          job_id?: string | null
          label?: string | null
          latitude?: number | null
          longitude?: number | null
          miles_from_previous?: number | null
          notes?: string | null
          sort_order?: number
          status?: string
          trip_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trip_stops_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "jobs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trip_stops_trip_id_fkey"
            columns: ["trip_id"]
            isOneToOne: false
            referencedRelation: "trips"
            referencedColumns: ["id"]
          },
        ]
      }
      trips: {
        Row: {
          completed_at: string | null
          created_at: string
          drive_minutes: number | null
          end_time: string | null
          id: string
          inspector_vehicle_id: string | null
          notes: string | null
          organization_id: string
          paused_at: string | null
          start_time: string | null
          started_at: string | null
          status: string
          title: string | null
          total_miles: number | null
          trip_date: string
          updated_at: string
          user_id: string
          work_minutes: number | null
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          drive_minutes?: number | null
          end_time?: string | null
          id?: string
          inspector_vehicle_id?: string | null
          notes?: string | null
          organization_id: string
          paused_at?: string | null
          start_time?: string | null
          started_at?: string | null
          status?: string
          title?: string | null
          total_miles?: number | null
          trip_date?: string
          updated_at?: string
          user_id: string
          work_minutes?: number | null
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          drive_minutes?: number | null
          end_time?: string | null
          id?: string
          inspector_vehicle_id?: string | null
          notes?: string | null
          organization_id?: string
          paused_at?: string | null
          start_time?: string | null
          started_at?: string | null
          status?: string
          title?: string | null
          total_miles?: number | null
          trip_date?: string
          updated_at?: string
          user_id?: string
          work_minutes?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "trips_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      vehicles: {
        Row: {
          company_id: string | null
          created_at: string | null
          created_by: string | null
          deleted_at: string | null
          id: string
          is_archived: boolean | null
          make: string | null
          mileage: string | null
          model: string | null
          trim: string | null
          updated_at: string | null
          updated_by: string | null
          vin: string
          year: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          is_archived?: boolean | null
          make?: string | null
          mileage?: string | null
          model?: string | null
          trim?: string | null
          updated_at?: string | null
          updated_by?: string | null
          vin: string
          year?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          deleted_at?: string | null
          id?: string
          is_archived?: boolean | null
          make?: string | null
          mileage?: string | null
          model?: string | null
          trim?: string | null
          updated_at?: string | null
          updated_by?: string | null
          vin?: string
          year?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_org_member: { Args: { _org_id: string }; Returns: boolean }
    }
    Enums: {
      app_role:
        | "super_admin"
        | "network_admin"
        | "company_admin"
        | "repair_shop_manager"
        | "inspector"
        | "technician"
        | "client"
        | "fleet_manager"
        | "mechanic"
        | "dispatcher"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: [
        "super_admin",
        "network_admin",
        "company_admin",
        "repair_shop_manager",
        "inspector",
        "technician",
        "client",
        "fleet_manager",
        "mechanic",
        "dispatcher",
      ],
    },
  },
} as const
