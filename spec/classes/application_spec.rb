require 'spec_helper'

describe 'katello::application' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      let (:params) { {} }

      let(:pre_condition) do
        <<-PUPPET
        class { 'katello::params':
          candlepin_oauth_secret => 'candlepin-secret',
        }
        PUPPET
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        if facts[:operatingsystemmajrelease] == '7'
          it { is_expected.to create_package('tfm-rubygem-katello') }
          it { is_expected.not_to create_package('tfm-rubygem-katello').that_requires('Anchor[katello::candlepin]') }
          it { is_expected.to create_package('rh-postgresql12-postgresql-evr') }
        else
          it { is_expected.to create_package('rubygem-katello') }
          it { is_expected.not_to create_package('rubygem-katello').that_requires('Anchor[katello::candlepin]') }
          it { is_expected.to create_package('postgresql-evr') }
        end

        it do
          is_expected.to create_foreman_config_entry('pulp_client_cert')
            .with_value('/etc/pki/katello/certs/pulp-client.crt')
            .that_requires(['Class[Certs::Pulp_client]', 'Foreman::Rake[db:seed]'])
        end

        it do
          is_expected.to create_foreman_config_entry('pulp_client_key')
            .with_value('/etc/pki/katello/private/pulp-client.key')
            .that_requires(['Class[Certs::Pulp_client]', 'Foreman::Rake[db:seed]'])
        end

        it do
          is_expected.to contain_service('httpd')
            .that_subscribes_to(['Class[Certs::Apache]', 'Class[Certs::Ca]'])
        end

        it do
          is_expected.to contain_file('/etc/foreman/plugins/katello.yaml')
            .that_notifies('Class[Foreman::Service]')
            .that_comes_before('Foreman::Rake[db:seed]')
        end

        it do
          is_expected.to create_foreman__config__apache__fragment('katello')
            .without_content()
            .with_ssl_content(%r{^<LocationMatch /rhsm\|/katello/api>$})
        end

        it do
          is_expected.to contain_foreman__dynflow__worker('worker-hosts-queue')
        end

        it 'should generate correct katello.yaml' do
          verify_exact_contents(catalogue, '/etc/foreman/plugins/katello.yaml', [
            ':katello:',
            '  :rest_client_timeout: 3600',
            '  :content_types:',
            '    :yum: true',
            '    :file: true',
            '    :deb: true',
            '    :puppet: true',
            '    :docker: true',
            '    :ostree: false',
            '  :candlepin:',
            '    :url: https://localhost:8443/candlepin',
            '    :oauth_key: "katello"',
            '    :oauth_secret: "candlepin-secret"',
            '    :ca_cert_file: /etc/pki/katello/certs/katello-default-ca.crt',
            '  :candlepin_events:',
            '    :ssl_cert_file: /etc/pki/katello/certs/java-client.crt',
            '    :ssl_key_file: /etc/pki/katello/private/java-client.key',
            '    :ssl_ca_file: /etc/pki/katello/certs/katello-default-ca.crt',
            '  :pulp:',
            '    :url: https://foo.example.com/pulp/api/v2/',
            '    :ca_cert_file: /etc/pki/katello/certs/katello-server-ca.crt',
            '  :use_pulp_2_for_content_type:',
            '    :docker: false',
            '    :file: false',
            '  :container_image_registry:',
            '    :crane_url: https://foo.example.com:5000',
            '    :crane_ca_cert_file: /etc/pki/katello/certs/katello-server-ca.crt'
          ])
        end

        it do
          is_expected.to create_file('/var/lib/pulp/katello-export')
            .with_ensure('directory')
            .with_owner('foreman')
            .with_group('foreman')
            .with_mode('0755')
            .that_requires('Exec[mkdir -p /var/lib/pulp/katello-export]')
        end
      end

      context 'with repo present' do
        let(:pre_condition) { 'include katello::repo' }

        it { is_expected.to compile.with_all_deps }

        if facts[:operatingsystemmajrelease] == '7'
          it { is_expected.to create_package('tfm-rubygem-katello').that_requires(['Anchor[katello::repo]', 'Yumrepo[katello]']) }
        else
          it { is_expected.to create_package('rubygem-katello').that_requires(['Anchor[katello::repo]', 'Yumrepo[katello]']) }
        end
      end

      context 'with parameters' do
        let(:params) do
          {
            rest_client_timeout: 4000,
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'should generate correct katello.yaml' do
          verify_exact_contents(catalogue, '/etc/foreman/plugins/katello.yaml', [
            ':katello:',
            '  :rest_client_timeout: 4000',
            '  :content_types:',
            '    :yum: true',
            '    :file: true',
            '    :deb: true',
            '    :puppet: true',
            '    :docker: true',
            '    :ostree: false',
            '  :candlepin:',
            '    :url: https://localhost:8443/candlepin',
            '    :oauth_key: "katello"',
            '    :oauth_secret: "candlepin-secret"',
            '    :ca_cert_file: /etc/pki/katello/certs/katello-default-ca.crt',
            '  :candlepin_events:',
            '    :ssl_cert_file: /etc/pki/katello/certs/java-client.crt',
            '    :ssl_key_file: /etc/pki/katello/private/java-client.key',
            '    :ssl_ca_file: /etc/pki/katello/certs/katello-default-ca.crt',
            '  :pulp:',
            '    :url: https://foo.example.com/pulp/api/v2/',
            '    :ca_cert_file: /etc/pki/katello/certs/katello-server-ca.crt',
            '  :use_pulp_2_for_content_type:',
            '    :docker: false',
            '    :file: false',
            '  :container_image_registry:',
            '    :crane_url: https://foo.example.com:5000',
            '    :crane_ca_cert_file: /etc/pki/katello/certs/katello-server-ca.crt',
          ])
        end
      end

      context 'with inherited parameters' do
        let :pre_condition do
          <<-EOS
          class {'katello::globals':
            enable_ostree => true,
          }
          #{super()}
          EOS
        end

        it { is_expected.to compile.with_all_deps }

        it 'should generate correct katello.yaml' do
          verify_exact_contents(catalogue, '/etc/foreman/plugins/katello.yaml', [
            ':katello:',
            '  :rest_client_timeout: 3600',
            '  :content_types:',
            '    :yum: true',
            '    :file: true',
            '    :deb: true',
            '    :puppet: true',
            '    :docker: true',
            '    :ostree: true',
            '  :candlepin:',
            '    :url: https://localhost:8443/candlepin',
            '    :oauth_key: "katello"',
            '    :oauth_secret: "candlepin-secret"',
            '    :ca_cert_file: /etc/pki/katello/certs/katello-default-ca.crt',
            '  :candlepin_events:',
            '    :ssl_cert_file: /etc/pki/katello/certs/java-client.crt',
            '    :ssl_key_file: /etc/pki/katello/private/java-client.key',
            '    :ssl_ca_file: /etc/pki/katello/certs/katello-default-ca.crt',
            '  :pulp:',
            '    :url: https://foo.example.com/pulp/api/v2/',
            '    :ca_cert_file: /etc/pki/katello/certs/katello-server-ca.crt',
            '  :use_pulp_2_for_content_type:',
            '    :docker: false',
            '    :file: false',
            '  :container_image_registry:',
            '    :crane_url: https://foo.example.com:5000',
            '    :crane_ca_cert_file: /etc/pki/katello/certs/katello-server-ca.crt'
          ])
        end
      end

      context 'with candlepin' do
        let(:pre_condition) { super() + 'include katello::candlepin' }

        it { is_expected.to compile.with_all_deps }

        if facts[:operatingsystemmajrelease] == '7'
          it { is_expected.to create_package('tfm-rubygem-katello').that_requires('Anchor[katello::candlepin]') }
        else
          it { is_expected.to create_package('rubygem-katello').that_requires('Anchor[katello::candlepin]') }
        end
      end

      context 'with pulp' do
        # post condition because things are compile order dependent
        let(:post_condition) { 'include katello::pulp' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_exec('mkdir -p /var/lib/pulp/katello-export').that_requires(['Anchor[katello::pulp]']) }
      end
    end
  end
end
