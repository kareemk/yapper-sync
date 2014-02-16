module Yapper::Sync
  module Event
    extend self

    def attach(attachment)
      params = {
        :attachment => attachment.metadata
      }
      request = http_client.multipartFormRequestWithMethod(
        'POST',
        path: Yapper::Sync.attachment_path,
        parameters: params.as_json,
        constructingBodyWithBlock: lambda { |form_data|
            form_data.appendPartWithFileData(UIImageJPEGRepresentation(attachment.data, 0.8),
                                             name: "attachment[data]",
                                             fileName: attachment.name,
                                             mimeType: 'image/jpg')
        })

      if process(request)
        Yapper::Log.info "[Yapper::Sync::Event][ATTACHMENT][#{attachment.id}]"
        :success
      else
        :failure
      end
    end

    def create(instance, type)
      params =  {
        :event => {
          :model    => instance.sync.model,
          :model_id => instance.sync.id,
          :type     => type,
          :delta    => instance.sync.delta
        }
      }
      if instance._attachments
        params.merge!(:attachments => instance._attachments)
      end

      request = http_client.requestWithMethod(
        'POST',
        :path => Yapper::Sync.data_path,
        :parameters => params.as_json)

      if operation = process(request)
        attrs = operation.responseJSON.deep_dup
        Yapper::Log.info "[Yapper::Sync::Event][POST][#{instance.model_name}] #{attrs}"

        new_attrs = {}
        attrs.each do |k, v|
          new_attrs[k] = v if instance.respond_to?(k) && instance.send(k).nil?
        end
        Yapper::Sync.disabled { instance.reload.update_attributes(new_attrs) }
        :success
      else
        :failure
      end
    rescue Exception => e
      if e.is_a?(NSException)
        Yapper::Log.error "[Yapper::Sync][CRITICAL][#{instance.model_name}] #{e.reason}: #{e.callStackSymbols}"
      else
        Yapper::Log.error "[Yapper::Sync][CRITICAL][#{instance.model_name}] #{e.message}: #{e.backtrace.join('::')}"
      end
      :critical
    end

    def get
      request = http_client.requestWithMethod(
        'GET',
        path: Yapper::Sync.data_path,
        parameters: { :since => Yapper::Config.get(:last_event_id) }
      )

      instances = []
      begin
        if operation = process(request)
          events = compact(operation.responseJSON)
          return events if events.empty?

          if events.first['model'] == 'User'
            instances << handle(events.shift)
          end

          events.each do |event|
            Yapper::DB.instance.execute do |txn|
              instances << handle(event)
              Yapper::Config.set(:last_event_id, event['created_at'])
            end
          end
        end
      rescue Exception => e
        Yapper::Log.error "[Yapper::Sync::Event][FAILURE] #{e.message}: #{e.backtrace.join('::')}"
      end

      instances.compact
    end

    private

    def handle(event)
      Yapper::Log.info "[Yapper::Sync::Event][GET][#{event['type']}][#{event['model']}] #{event['delta']}"

      model = Object.qualified_const_get(event['model'])
      instance = nil
      if event['type'] == 'create'
        instance = model.new(event['delta']) # XXX shouldn't need to pass in delta
      else
        instance = model.find(event['model_id'])
      end

      if instance
        # XXX Return array of updates vs. overwriting entire object
        Yapper::Sync.disabled { instance.update_attributes(event['delta']) }
      else
        Yapper::Log.error  "Model instance not found!. This is not good!"
      end

      instance
    end

    def compact(events)
      event_lookup = {}; compact_events = []
      events.each_with_index do |event, i|
        case event['type']
        when 'create'
          event_lookup[event['model_id']] = compact_events.count
          compact_events << event
        when 'update'
          if index = event_lookup[event['model_id']]
            create_event = compact_events[index].dup
            create_event['delta'] = recursive_merge(create_event['delta'], event['delta'])
            compact_events[index] = create_event
          else
            compact_events << event
          end
        else
          raise "Only 'update' AND 'create' supported"
        end
      end
      compact_events
    end

    def http_client
      @http_client ||= begin
                         client = AFHTTPClient.alloc.initWithBaseURL(NSURL.URLWithString(Yapper::Sync.base_url))
                         client.setParameterEncoding(AFJSONParameterEncoding)
                         client
                       end
      @http_client.setAuthorizationHeaderWithToken(Yapper::Sync.access_token.call)
      @http_client.setDefaultHeader('DEVICEID', value: UIDevice.currentDevice.identifierForVendor.UUIDString)
    end

    def process(request)
      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        operation
      else
        Yapper::Log.error "[Yapper::Sync::Event][FAILURE] #{operation.error.localizedDescription}"
        false
      end
    end

    def recursive_merge(h1, h2)
      return h1 unless h1.is_a?(Array) || h1.is_a?(Hash)

      result = h1.dup; h2 = h2.dup
      h2.each_pair do |k,v|
        tv = h1[k]
        if tv.is_a?(Hash) && v.is_a?(Hash)
          result[k] = recursive_merge(tv, v)
        elsif tv.is_a?(Array) && v.is_a?(Array)
          v = v.dup
          result[k] = tv.map do |_tv|
            if match = v.find { |_v| _tv.is_a?(Hash) && _v.is_a?(Hash) && _tv['id'] == _v['id'] }
              v.delete(match)
              recursive_merge(_tv, match)
            else
              _tv
            end
          end
          result[k] += v
        else
          result[k] = v
        end
      end
      result
    end
  end
end
