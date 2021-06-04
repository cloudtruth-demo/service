require "graphql/client"
require "graphql/client/http"

Parameter = Struct.new(:key, :value, :secret, :original_key, keyword_init: true)

def self.CtApi(api_key:, api_url: nil)
  api_url ||= "https://api.cloudtruth.com/graphql"

  clazz = Class.new do

    cattr_accessor :http, :schema, :client, :queries
    attr_accessor :environment, :organization

    self.http = ::GraphQL::Client::HTTP.new(api_url) do
      define_method :headers do |context = {}|
        { "User-Agent": "kubetruth/#{Kubetruth::VERSION}", "Authorization": "Bearer #{api_key}" }
      end
    end
    self.schema = ::GraphQL::Client.load_schema(http)
    self.client = ::GraphQL::Client.new(schema: schema, execute: http)
    self.client.allow_dynamic_queries = true

    self.queries = {}
    self.queries[:OrganizationsQuery] = client.parse <<~GRAPHQL
      query {
        viewer {
          memberships {
            nodes {
              organization {
                id
                name
              }
            }
          }
        }
      }
    GRAPHQL

    self.queries[:EnvironmentsQuery] = client.parse <<~GRAPHQL
      query($organizationId: ID) {
        viewer {
          organization(id: $organizationId) {
            environments {
              nodes {
                id
                name
              }
            }
          }
        }
      }
    GRAPHQL

    self.queries[:ProjectsQuery] = client.parse <<~GRAPHQL
      query($organizationId: ID) {
        viewer {
          organization(id: $organizationId) {
            projects {
              nodes {
                id
                name
              }
            }
          }
        }
      }
    GRAPHQL

    self.queries[:ParametersQuery] = client.parse <<~GRAPHQL
      query($organizationId: ID, $environmentId: ID, $projectName: String, $searchTerm: String) {
        viewer {
          organization(id: $organizationId) {
            project(name: $projectName) {
              parameters(searchTerm: $searchTerm, orderBy: { keyName: ASC }) {
                nodes {
                  id
                  keyName
                  isSecret
                  environmentValue(environmentId: $environmentId) {
                    parameterValue
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    def initialize(environment: "default", organization: nil)
      @environment = environment
      @organization = organization
    end

    def organizations
      @organizations ||= begin
                           result = client.query(self.queries[:OrganizationsQuery])
                           Hash[result&.data&.viewer&.memberships&.nodes&.collect {|o| [o.organization.name, o.organization.id] }]
                         end
    end

    def environments
      @environments ||= begin
                          variables = {}
                          if @organization
                            org_id = self.organizations[@organization] || raise("Unknown organization: #{@organization}")
                            variables[:organizationId] = org_id
                          end

                          result = client.query(self.queries[:EnvironmentsQuery], variables: variables)
                          Hash[result&.data&.viewer&.organization&.environments&.nodes&.collect {|e| [e.name, e.id] }]
                        end
    end

    def projects
      variables = {}
      if @organization
        org_id = self.organizations[@organization] || raise("Unknown organization: #{@organization}")
        variables[:organizationId] = org_id
      end

      result = client.query(self.queries[:ProjectsQuery], variables: variables)
      Hash[result&.data&.viewer&.organization&.projects&.nodes&.collect {|e| [e.name, e.id] }]
    end

    def organization_names
      organizations.keys
    end

    def environment_names
      environments.keys
    end

    def project_names
      projects.keys
    end

    def parameters(searchTerm: "", project: nil)
      env_id = self.environments[@environment] || raise("Unknown environment: #{@environment}")
      variables = {searchTerm: searchTerm, environmentId: env_id.to_s}

      if @organization
        org_id = self.organizations[@organization] || raise("Unknown organization: #{@organization}")
        variables[:organizationId] = org_id
      end

      variables[:projectName] = project if project.present?

      result = client.query(self.queries[:ParametersQuery], variables: variables)

      result&.data&.viewer&.organization&.project&.parameters&.nodes&.collect do |e|
        Kubetruth::Parameter.new(key: e.key_name, value: e.environment_value.parameter_value, secret: e.is_secret)
      end
    end

  end

  @ident ||= 0
  @ident += 1
  Kubetruth.const_set(:"CtApi_#{@ident}", clazz)

  return clazz
end
