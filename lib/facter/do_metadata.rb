# frozen_string_literal: true

# Expose DigitalOcean metadata as a fact
#
# This fact purposefully excludes `vendor_data` and `user_data` values
# as these are often large and often not useful enough to justify storing
# in a cache like PuppetDB.
#
# @see https://developers.digitalocean.com/documentation/metadata/
Facter.add(:do_metadata) do
  confine do
    dmi = Facter.value('dmi')

    if dmi.nil? || !dmi['manufacturer'].respond_to?(:casecmp?)
      false
    else
      dmi['manufacturer'].casecmp?('digitalocean')
    end
  end

  setcode do
    require 'json'
    require 'net/http'

    begin
      Net::HTTP.start('169.254.169.254', 80, open_timeout: 5, read_timeout: 5) do |http|
        result = http.get('/metadata/v1.json')

        # Raises a Net::HTTPExceptions error if the request failed
        result.value

        data = JSON.parse(result.body)
        # This is a large blob of MIME-encoded data that is better off
        # not stored in PuppetDB.
        data.delete('vendor_data')
        # user-supplied cloud-init script that also doesn't need to be
        # stored in PuppetDB.
        data.delete('user_data')

        data
      end
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, Net::HTTPExceptions => e
      Facter.log_exception(
        e,
        'DigitalOcean metadata request to http://169.254.169.254:80/metadata/v1.json failed: (%{class}) %{message}' % {class: e.class, message: e.message},
      )
      nil
    end
  end
end
