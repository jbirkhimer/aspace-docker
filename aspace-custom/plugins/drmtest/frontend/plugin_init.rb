
my_routes = File.join(File.dirname(__FILE__), "routes.rb")
# ArchivesSpace::Application.config.paths['config/routes'].concat(my_routes)
# if ArchivesSpace::Application.respond_to?(:extend_aspace_routes)
ArchivesSpace::Application.extend_aspace_routes(my_routes)
#   else
#     ArchivesSpace::Application.config.paths['config/routes'].concat([my_routes])
#     end
#

# my_routes = [File.join(File.dirname(__FILE__), "routes.rb")]
# ArchivesSpace::Application.config.paths['config/routes'].concat(my_routes)

