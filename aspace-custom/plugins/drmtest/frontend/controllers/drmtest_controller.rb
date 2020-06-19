module Enumerable
  def flatten_with_path(parent_prefix = nil)
    res = {}

    self.each_with_index do |elem, i|
      if elem.is_a?(Array)
        k, v = elem
      else
        k, v = i, elem
      end

      key = parent_prefix ? "#{parent_prefix}.#{k}" : k # assign key name for result hash

      if v.is_a? Enumerable
        res.merge!(v.flatten_with_path(key)) # recursive call to flatten child elements
      else
        res[key] = v
      end
    end

    res
  end
end

class DrmtestController < ApplicationController
  require 'csv'

  skip_before_filter :unauthorised_access

  def gen

    uri_source = '' + params['source'].to_s
    regex = '' + params['regex'].to_s
    
    style = '' + params['style'].to_s

    self.response.headers["Content-Type"] = "text/csv"
    self.response.headers["Content-Disposition"] = "attachment; filename=aspace-csv-#{Time.now.to_i}.csv"
    self.response.headers['Last-Modified'] = Time.now.ctime.to_s
      
    params = params_for_backend_search

    Rails.logger.info('drmtest-'+uri_source)

    ['resource','digital_object','accession','subject','location','event'].each do |type|
      if type.in? uri_source
        Rails.logger.info('drmtest-uri_source: '+ uri_source)
        params = params_for_backend_search.merge({"filter_term[]" => '{"primary_type":"'+type+'"}'})
      end
    end

    case uri_source
    when /agent/i
      params = params_for_backend_search.merge({"filter_term[]" => '{"primary_type":"agent_corporate_entity"}'}).merge({"filter_term[]" => '{"primary_type":"agent_person"}'})
    else
    end

    Search.build_filters(params)
    params['dt'] = 'json'
    page = 1
    this_page = 0
    last_page = 1
    fullset = Array.new
    while this_page <= last_page do
      params['page'] = page.to_s
      Rails.logger.info(params)
      response = JSONModel::HTTP::post_form("/repositories/#{session[:repo_id]}/search", params)
      Rails.logger.info('Response for drmtest page: ' +page.to_s + ', Code:' + response.code)
      if response.code == '200'
        fullset = fullset.concat(ASUtils.json_parse(response.body)['results'])
      end
      this_page = ASUtils.json_parse(response.body)['this_page'].to_i
      last_page = ASUtils.json_parse(response.body)['last_page'].to_i
      page += 1
    end

    #    params['page'] = '1'
    #    response = JSONModel::HTTP::post_form("/repositories/#{session[:repo_id]}/search", params)
    #    Rails.logger.info('Response for drmtest gen: ' + response.code)
    #    if response.code == '200'
    #      fullset = fullset.concat(ASUtils.json_parse(response.body)['results'])
    #    end

    fullset.each { |result|
                      result['json_drm'] = ASUtils.json_parse(result['json'])
                      result.delete('json')
                 }

    #render :json => fullset

    csvout = CSV.generate({:col_sep => "\t|\t"}) do |csv|
      format_results(fullset).each { |fr| csv << fr }
    end

    #render :plain => csvout

    #render :json => fullset #.flatten_with_path

    fullflat = Array.new
    fullset.each { |result| fullflat << format_result(result.flatten_with_path.sort.to_h, style)
#      fullflat << result.flatten_with_path.sort.to_h.select {|k,v| k.to_s.match(regex) } 
    }

    case style
    when 'work'
      header = ['Record Type', 'Identifier', 'Level', 'Component ID', 'Display', 'Type', 'Indicator', 'Type_2', 'Indicator_2',
        'Type_3', 'Indicator_3']
    when 'pull'
      header = ['Record Type', 'Identifier', 'Level', 'Component ID', 'Display', 'Type', 'Indicator', 'Type_2', 'Indicator_2',
        'Type_3', 'Indicator_3', 'Restrictions', 'Locations']
    else
      header = ['NO HEADER', 'NO DATA']
    end
    
    #csvout = CSV.generate({:col_sep => "\t|\t"}) do |csv|
    csvout = CSV.generate() do |csv|
      csv << header
      fullflat.each { |r| csv << r }
    end
    render :plain => csvout
      
#    render :json => fullflat

    #    if response.code == '400'
    #      search_params = params_for_backend_search.merge({"facet[]" => SearchResultData.ACCESSION_FACETS})
    #      search_params["type[]"] = "accession"
    #      uri = "/repositories/#{session[:repo_id]}/search"
    #      csv_response( uri, search_params )
    #    else
    #      #render :json => ASUtils.json_parse(response.body) #['total_hits']
    #      render :json => fullset #['total_hits']
    #    end
  end

  
  
  def format_result(result = {}, style = '')
    listpull = {
      'archival_object' => [
        '^primary_type$',
        'json_drm.ref_id$',
        'json_drm.level$',
        'json_drm.component_id',
        '^(display_string|title)',
        'sub_container.top_container._resolved.type',
        'sub_container.top_container._resolved.indicator',
        'sub_container.type_2',
        'sub_container.indicator_2',
        'sub_container.type_3',
        'sub_container.indicator_3',
      ],
      'resource' => [
        '^primary_type$',
        'json_drm.*ead_id',
        'json_drm.*level',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'sub_container.top_container._resolved.type',
        'sub_container.top_container._resolved.indicator',
        'sub_container.type_2',
        'sub_container.indicator_2',
        'sub_container.type_3',
        'sub_container.indicator_3',
      ],
      'subject' => [
        '^primary_type$',
        'json_drm.*authority_id',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'json_drm.*term_type',
      ],
      'top_container' => [
        '^primary_type$',
        'barcode',
        'json_drm.*level',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'json_drm.type',
        'json_drm.indicator',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        '(json_drm.*active_restrictions.*begin|json_drm.*active_restrictions.*end|json_drm.*active_restrictions.*display_string|json_drm.*active_restrictions.*\.type)',
        'json_drm.*container_locations.*title',
      ],
      'digital_object' => [
        '^primary_type$',
        'digital_object_id',
        'json_drm.*level',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'json_drm.*file_versions.*use-statement',
        'json_drm.*file_versions.*file_uri',
        ],
      'collection_management' => [],
      nil => [],
      '' => []
    }
    listwork = {
      'archival_object' => [
        '^primary_type$',
        'json_drm.ref_id$',
        'json_drm.level$',
        'json_drm.component_id',
        '^(display_string|title)',
        'sub_container.top_container._resolved.type',
        'sub_container.top_container._resolved.indicator',
        'sub_container.type_2',
        'sub_container.indicator_2',
        'sub_container.type_3',
        'sub_container.indicator_3',
      ],
      'resource' => [
        '^primary_type$',
        'json_drm.*ead_id',
        'json_drm.*level',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'sub_container.top_container._resolved.type',
        'sub_container.top_container._resolved.indicator',
        'sub_container.type_2',
        'sub_container.indicator_2',
        'sub_container.type_3',
        'sub_container.indicator_3',
      ],
      'subject' => [
        '^primary_type$',
        'json_drm.*authority_id',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'json_drm.*term_type',
      ],
      'top_container' => [
        '^primary_type$',
        'barcode',
        'json_drm.*level',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'json_drm.type',
        'json_drm.indicator',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
        'json_drm.*blank_column',
      ],
      'digital_object' => [
        '^primary_type$',
        'digital_object_id',
        'json_drm.*level',
        'json_drm.*blank_column',
        '^(display_string|title)',
        'json_drm.*file_versions.*use-statement',
        'json_drm.*file_versions.*file_uri',
        ],
      'collection_management' => [],
      nil => [],
      '' => []
    }
    out = Array.new
    case style
    when 'pull'
      listpull[result['primary_type']].try(:each) do |item|
        out << (result.select {|k,v| k.to_s.match(item)}).values.join('; ')
      end
      if listpull[result['primary_type']].nil?
        out << result['primary_type'].to_s
        out << '';
        out << '';
        out << '';
        out << result['title'].to_s + '; ' + result['display_string'].to_s        
      end
    when 'work'
      listwork[result['primary_type']].try(:each) do |item|
        out << (result.select {|k,v| k.to_s.match(item)}).values.join('; ')
      end
      if listwork[result['primary_type']].nil?
        out << result['primary_type'].to_s
        out << '';
        out << '';
        out << '';
        out << result['title'].to_s + '; ' + result['display_string'].to_s        
      end
    else
      out << ['NO DATA', 'NO DATA', style , 'NO DATA']
    end
    out
  end

  def format_results(fullset = {})
    fulloutput = Array.new

    cnt = 1
    fullset.each do |result|
      out = Array.new
      out << cnt.to_s
      cnt += 1
      primary_type = '' + result['primary_type']
      case primary_type
      when /archival_object/i
        ['primary_type', 'ref_id', 'level', 'title'].each { |x| out << result[x] }
      when /top_container/i
        ['primary_type', 'ref_id', 'level', 'title'].each { |x| out << result[x] }
      else
        ['primary_type', 'ref_id', 'level', 'title'].each { |x| out << result[x] }
      end
      fulloutput << out
    end
    return fulloutput
  end

  def csv_response(request_uri, params = {} )
    self.response.headers["Content-Type"] = "text/csv"
    self.response.headers["Content-Disposition"] = "attachment; filename=aspace-#{Time.now.to_i}.csv"
    self.response.headers['Last-Modified'] = Time.now.ctime.to_s
    self.response.headers['X-requesturi'] = request_uri
    #params["dt"] = "csv"
    params['filter_term[]'] = '{"primary_type":"top_container"}'
    params['q'] = 'sally ride'
    params["dt"] = "json"
    params["page_size"] = "999999"
    self.response.headers['X-params'] = params.as_json.to_json

    Rails.logger.info(params.as_json.to_json)

    #self.response_body = Enumerator.new do |y|
    new_response_body = Enumerator.new do |y|
      xml_response(request_uri, params) do |chunk, percent|
        y << chunk if !chunk.blank?
      end
    end

    results = JSON.parse(new_response_body.to_a.join)
    outstr = ""
    outarr = Array.new
    locations = Hash.new
    results['results'].each do |result|
      locations[result['id']] = result['display_string']
    end

    csv_string = CSV.generate do |csv|
      #csv << ["A","B","C","D","E","F","G","H","I","J"]
      results['results'].each do |result|
        element = JSON.parse(result['json'])
        outarr.push(element)
        #Rails.logger.info(flatten(element))
        #csv << flatten(element)
        #csv << element.to_a
        out = Array.new
        #out << "FORMATED"
        out << result['primary_type']
        out << (element['ref_id'] != nil ? element['ref_id'] : "")
        out << if /^\d+$/ =~ result['title']
          "'" + result['title']
        else
          result['title']
        end
        if result['jsonmodel_type'] == 'top_container'
          out << element['type']
          out << element['indicator']
          #out << element['active_restrictions']
        end
        #out << element['active_restrictions']
        if element['active_restrictions'].is_a?Array
          locs = Array.new
          element['active_restrictions'].each do |loc|
            locs << loc['restriction_note_type']
            locs << "FROM:"+ (loc['begin'] != nil ? loc['begin']:"") + "-UNTIL:" + (loc['end'] != nil ? loc['end'] : "")
            locs << loc['local_access_restriction_type'].join(",")
          end
          out << locs.join("; ")
        end
        if element['container_locations'].is_a?Array
          locs = Array.new
          element['container_locations'].each do |loc|
            locs << loc['_resolved']['title']
          end
          out << locs.join("; ")
        end
        if result['top_container_uri_u_sstr'].is_a?Array
          result['top_container_uri_u_sstr'].each do |container|
            if locations[container]
              out << locations[container]
            else
              out << container
            end
          end
        end
        if element['instances'].is_a?Array
          element['instances'].each do |instance|
            obj = Hash.new
            if instance.is_a?Hash
              obj = instance['sub_container']
              Rails.logger.info(obj)
            end
            if obj.is_a?Hash
              obj = obj['top_container']
            end
            if obj.is_a?Hash
              obj = obj['_resolved']
            end
            if obj.is_a?Hash
              out << obj['long_display_string']
            end
            if (obj.is_a?Hash and obj['active_restrictions'].is_a?Array)
              locs = Array.new
              obj['active_restrictions'].each do |loc|
                locs << loc['restriction_note_type']
                locs << "FROM:"+ (loc['begin'] != nil ? loc['begin']:"") + "-UNTIL:" + (loc['end'] != nil ? loc['end'] : "")
                locs << loc['local_access_restriction_type'].join(",")
              end
              out << locs.join("; ")
            end
          end
        end
        csv << out
        out = Array.new
        out << "SOURCE"
        out << "\"" + result.to_json.as_json + "\""
        #csv << out
      end
      csv << Array.new
      csv << Array.new
      csv << Array.new
      csv << Array.new
      csv << Array.new
      out = Array.new
      #out << results.to_json.as_json
      csv << out
    end
    #self.response_body = results.to_json.as_json
    self.response_body = csv_string #+ "\n\n\n\n" + "\"BEGIN" + results.to_json.as_json + "\""
  end

  def simple(obj)
    out = Array.new
    out << obj['primary_type']
    out << obj['title']

    return out
  end

  def flatten(obj)
    #Rails.logger.info(obj.to_s)
    out = Array.new
    if obj.is_a?String
      #Rails.logger.info(obj.to_s)
      out << obj
    end
    if obj.is_a?Hash
      case obj['jsonmodel_type']
      when "subject"
        out << obj['title']
      when "agent_family"
        out << obj['title']
      when "agent_person"
        out << obj['title']
      else
        obj.each do |k,v|
          case k
          when 'create_time'
          when 'system_mtime'
          when 'user_mtime'
          when 'created_by'
          when 'last_modified_by'
          when 'suppressed'
          when 'language'
          when 'language'
          else
            out += (flatten(v))
          end
        end
      end
    end
    if obj.is_a?Array
      arr = Array.new
      obj.each do |v|
        arr << (flatten(v).join(";"))
      end
      out += arr
    end
    return out
  end

  def xml_response(request_uri, params = {})
    JSONModel::HTTP::stream(request_uri, params) do |res|
      size, total = 0, res.header['Content-Length'].to_i
      res.read_body do |chunk|
        size += chunk.size
        percent = total > 0 ? ((size * 100) / total) : 0
        yield chunk, percent
      end
    end
  end

end

