class ResourceUpdateMonitor

  CHANGED_RECORD_QUERIES = {

    :updated_resources =>
      ('select DISTINCT r.id, r.title, r.identifier, r.ead_id, r.ead_location, r.repo_id, r.publish, r.suppressed' +
       ' from resource r' +
       ' where system_mtime >= ?'),

    :updated_archival_objects =>
      ('select DISTINCT r.id, r.title, r.identifier, r.ead_id, r.ead_location, r.repo_id, r.publish, r.suppressed ' +
       ' from resource r' +
       ' inner join archival_object ao on ao.root_record_id = r.id' +
       ' where ao.system_mtime >= ?'),

    :updated_digital_object_via_resource =>
      ('select DISTINCT r.id, r.title, r.identifier, r.ead_id, r.ead_location, r.repo_id, r.publish, r.suppressed' +
       ' from digital_object do' +
       ' inner join instance_do_link_rlshp rlshp on rlshp.digital_object_id = do.id' +
       ' inner join instance i on i.id = rlshp.instance_id' +
       ' inner join resource r on r.id = i.resource_id' +
       ' where do.system_mtime >= ?'),

    :updated_digital_object_via_ao =>
      ('select DISTINCT r.id, r.title, r.identifier, r.ead_id, r.ead_location, r.repo_id, r.publish, r.suppressed from digital_object do' +
       ' inner join instance_do_link_rlshp rlshp on rlshp.digital_object_id = do.id' +
       ' inner join instance i on i.id = rlshp.instance_id' +
       ' inner join archival_object ao on ao.id = i.archival_object_id' +
       ' inner join resource r on r.id = ao.root_record_id' +
       ' where do.system_mtime >= ?'),

    :updated_digital_object_component_via_resource =>
      ('select DISTINCT r.id, r.title, r.identifier, r.ead_id, r.ead_location, r.repo_id, r.publish, r.suppressed from digital_object_component doc' +
       ' inner join digital_object do on doc.root_record_id = do.id' +
       ' inner join instance_do_link_rlshp rlshp on rlshp.digital_object_id = do.id' +
       ' inner join instance i on i.id = rlshp.instance_id' +
       ' inner join resource r on r.id = i.resource_id' +
       ' where doc.system_mtime >= ?'),

    :updated_digital_object_component_via_ao =>
      ('select DISTINCT r.id, r.title, r.identifier, r.ead_id, r.ead_location, r.repo_id, r.publish, r.suppressed from digital_object_component doc' +
       ' inner join digital_object do on doc.root_record_id = do.id' +
       ' inner join instance_do_link_rlshp rlshp on rlshp.digital_object_id = do.id' +
       ' inner join instance i on i.id = rlshp.instance_id' +
       ' inner join archival_object ao on ao.id = i.archival_object_id' +
       ' inner join resource r on r.id = ao.root_record_id' +
       ' where doc.system_mtime >= ?'),
  }


  include JSONModel

  def initialize()
    @repo_id = nil
    @start_id = nil
    @end_id = nil
  end


  def repo_id(repo_id)
    @repo_id = repo_id
  end


  def identifier(start_id, end_id = nil)
    @start_id = start_id
    @end_id = end_id
    @parsed_start_id = JSON.parse(@start_id)
    @id_range = []
    if @end_id
      @parsed_end_id = JSON.parse(@end_id)
      @parsed_start_id.each_index do |ix|
        if @parsed_start_id[ix] && @parsed_end_id[ix]
          if @parsed_start_id[ix] < @parsed_end_id[ix]
            @id_range << {:low => @parsed_start_id[ix], :hi => @parsed_end_id[ix], :skip => false}
          else
            @id_range << {:hi => @parsed_start_id[ix], :low => @parsed_end_id[ix], :skip => false}
          end
        else
          @id_range << {:skip => true}
        end
      end
    end
  end


  def in_range(resource)
    return true unless @start_id && @end_id

    res_id = JSON.parse(resource[:identifier])

    res_id.each_index do |ix|
      next if @id_range[ix][:skip]
      return false unless res_id[ix]
      return false if res_id[ix] < @id_range[ix][:low] || res_id[ix] > @id_range[ix][:hi]
    end

    return true
  end


  def updates_since(timestamp)
    adds = {}
    removes = []
    mtime = Time.at(timestamp)

    DB.open do |db|

      CHANGED_RECORD_QUERIES.each do |_, query_sql|

        sql = query_sql
        params = [mtime]

        if @repo_id
          sql += ' AND r.repo_id in (%s)' % Array(@repo_id).map {|_| "?"}.join(', ')
          params.concat(Array(@repo_id))
        end

        if @start_id && !@end_id
          sql += mods.where(' AND r.identifier = ?')
          params << @start_id
        end

        ds = db[sql, *params]
        mods = ds.call(:select)

        mods.each do |res|
          next if adds.include?(res[:id])

          if in_range(res)
            if res[:publish] == 1 && res[:suppressed] == 0
              adds[res[:id]] = {
                'id' => res[:id],
                'title' => res[:title],
                'ead_id' => res[:ead_id],
                'ead_location' => res[:ead_location],
                'identifier' => JSON.parse(res[:identifier]),
                'repo_id' => res[:repo_id],
                'uri' => JSONModel(:resource).uri_for(res[:id], :repo_id => res[:repo_id]),
              }
            else
              removes << res[:id]
            end
          end
        end
      end

      dels = db[:deleted_records].where(Sequel.qualify(:deleted_records, :timestamp) > mtime)
             .select(:uri)

      dels.each do |res|
        # If this tombstone contains a '#', it refers to a nested record.  Not interested.
        next if res[:uri] =~ /#/

        ref = JSONModel.parse_reference(res[:uri])
        if ref[:type] == 'resource'
          if @repo_id
            repo = JSONModel.parse_reference(ref[:repository])
            removes << ref[:id] if @repo_id == repo[:id]
          else
            removes << ref[:id]
          end
        end
      end

    end

    {'timestamp' => timestamp, 'adds' => adds.values, 'removes' => removes}
  end

end
