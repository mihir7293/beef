#
#   Copyright 2011 Wade Alcorn wade@bindshell.net
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
module BeEF
  module Extension
    module Xssrays

      class Handler < WEBrick::HTTPServlet::AbstractServlet

        XS = BeEF::Core::Models::Xssraysscan
        XD = BeEF::Core::Models::Xssraysdetail
        HB = BeEF::Core::Models::HookedBrowser

        def do_GET(request, response)
          @request = request

          # verify if the request contains the hook token
          # raise an exception if it's null or not found in the DB
          beef_hook = get_param(@request.query, 'hbsess') || nil
          raise WEBrick::HTTPStatus::BadRequest,
                "[XSSRAYS] Invalid beefhook id: the hooked browser cannot be found in the database" if beef_hook.nil? || HB.first(:session => beef_hook) == nil

          rays_scan_id = get_param(@request.query, 'raysid') || nil
          raise WEBrick::HTTPStatus::BadRequest, "[XSSRAYS] Raysid is null" if rays_scan_id.nil?

          if (get_param(@request.query, 'action') == 'ray')
            # we received a ray
            parse_rays(rays_scan_id)
          else
            if (get_param(@request.query, 'action') == 'finish')
              # we received a notification for finishing the scan
              finalize_scan(rays_scan_id)
            else
              #invalid action
              raise WEBrick::HTTPStatus::BadRequest, "[XSSRAYS] Invalid action"
            end
          end
        end

        # parse incoming rays: rays are verified XSS, as the attack vector is calling back BeEF when executed.
        def parse_rays(rays_scan_id)
          xssrays_scan = XS.first(:id => rays_scan_id)
          hooked_browser = HB.first(:session => get_param(@request.query, 'hbsess'))

          if (xssrays_scan != nil)
            xssrays_detail = XD.new(
                :hooked_browser_id => hooked_browser.id,
                :vector_name => get_param(@request.query, 'n'),
                :vector_method => get_param(@request.query, 'm'),
                :vector_poc => get_param(@request.query, 'p'),
                :xssraysscan_id => xssrays_scan.id
            )
            xssrays_detail.save
          end
          print_info("[XSSRAYS] Received ray from HB with ip [#{hooked_browser.ip.to_s}], hooked on domain [#{hooked_browser.domain.to_s}]")
          print_debug("[XSSRAYS] Ray info: \n #{@request.query}")
        end

        # finalize the XssRays scan marking the scan as finished in the db
        def finalize_scan(rays_scan_id)
          xssrays_scan = BeEF::Core::Models::Xssraysscan.first(:id => rays_scan_id)

          if (xssrays_scan != nil)
            xssrays_scan.update(:is_finished => true, :scan_finish => Time.now)
            print_info("[XSSRAYS] Scan id [#{xssrays_scan.id}] finished at [#{xssrays_scan.scan_finish}]")
          end
        end

        #assist function for getting parameter from hash
        def get_param(query, key)
          return nil if query[key].nil?
          query[key]
        end
      end
    end
  end
end
