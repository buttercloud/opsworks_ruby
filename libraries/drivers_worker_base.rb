# frozen_string_literal: true

module Drivers
  module Worker
    class Base < Drivers::Base
      include Drivers::Dsl::Output
      include Drivers::Dsl::Packages

      def setup
        handle_packages
      end

      def validate_app_engine; end

      protected

      def add_worker_monit
        opts = { application: app['shortname'], name: app['name'], out: out, deploy_to: deploy_dir(app),
                 environment: environment, adapter: adapter, app_shortname: app['shortname'],
                 source_cookbook: worker_monit_template_cookbook }

        context.template File.join(node['monit']['basedir'], "#{opts[:adapter]}_#{opts[:application]}.monitrc") do
          mode '0640'
          source "#{opts[:adapter]}.monitrc.erb"
          cookbook opts[:source_cookbook].to_s
          variables opts
        end

        context.execute 'monit reload'
      end

      def worker_monit_template_cookbook
        node['deploy'][app['shortname']][driver_type]['monit_template_cookbook'] || context.cookbook_name
      end

      def restart_monit
        return if ENV['TEST_KITCHEN'] # Don't like it, but we can't run multiple processes in Docker on travis

        (1..process_count).each do |process_number|
          context.execute "monit restart #{adapter}_#{app['shortname']}-#{process_number}" do
            retries 3
          end
        end
      end

      def unmonitor_monit
        (1..process_count).each do |process_number|
          context.execute "monit unmonitor #{adapter}_#{app['shortname']}-#{process_number}" do
            retries 3
          end
        end
      end

      def process_count
        [out[:process_count].to_i, 1].max
      end

      def environment
        framework = Drivers::Framework::Factory.build(context, app, options)
        app['environment'].merge(framework.out[:deploy_environment] || {})
                          .merge('HOME' => node['deployer']['home'], 'USER' => node['deployer']['user'])
      end
    end
  end
end
