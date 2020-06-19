# editable_external_ids
An ArchivesSpace plugin that adds the ability for Administrators to edit external ids

## How to install it

First, you need to set the configuration to allow all users to see external ids in both
record forms and readonly views:

     AppConfig[:show_external_ids] = true

To install, just activate the plugin in your config/config.rb file by
including an entry such as:

     # If you have other plugins loaded, just add 'editable_external_ids' to
     # the list
     AppConfig[:plugins] = ['local', 'other_plugins', 'editable_external_ids']

And then clone the `editable_external_ids` repository into your
ArchivesSpace plugins directory.  For example:

     cd /path/to/your/archivesspace/plugins
     git clone https://github.com/hudmol/editable_external_ids.git

## v1.4+ Compatibility

This plugin is compatible with ArchivesSpace v1.4+. If you're after similar behaviour for
v1.2 or v1.3, please have a look at our other plugin https://github.com/hudmol/visible_external_ids.
