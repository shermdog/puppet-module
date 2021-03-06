require 'puppet/resource_api'
require 'puppet/resource_api/simple_provider'

require_relative('../../util/network_device/meraki_organization/device')

# Implementation for the meraki_admin type using the Resource API.
class Puppet::Provider::MerakiAdmin::MerakiAdmin
  def set(context, changes)
    changes.each do |name, change|
      is = change[:is].nil? ? { name: name, ensure: 'absent' } : change[:is]
      should = change[:should].nil? ? { name: name, ensure: 'absent' } : change[:should]

      if is[:ensure].to_s == 'absent' && should[:ensure].to_s == 'present'
        context.creating(name) do
          create(context, name, should)
        end
      elsif is[:ensure].to_s == 'present' && should[:ensure].to_s == 'present'
        context.updating(name) do
          update(context, name, is[:id], should)
        end
      elsif is[:ensure].to_s == 'present' && should[:ensure].to_s == 'absent'
        context.deleting(name) do
          delete(context, is[:id])
        end
      end
    end
  end

  def get(context)
    admins = context.device.dapi.list_admins(context.device.orgid)

    return [] if admins.nil?

    admins.map do |admin|
      {
        fullname: admin['name'],
        ensure: 'present',
        email: admin['email'],
        id: admin['id'],
        orgaccess: admin['orgAccess'],
        # Order of this array does not matter to the Meraki API, sort to match canonicalize
        networks: admin['networks'].sort_by { |k| k['id'] },
        tags: admin['tags'].sort_by { |k| k['tag'] },
      }
    end
  end

  def create(context, _name, should)
    # convert puppet attr names to meraki api names
    should.delete(:ensure)
    should[:name] = should.delete(:fullname)
    should[:orgAccess] = should.delete(:orgaccess)

    context.device.dapi.add_admin(context.device.orgid, should)
  end

  def update(context, _name, id, should)
    # convert puppet attr names to meraki api names
    should.delete(:ensure)
    should[:name] = should.delete(:fullname)
    should[:orgAccess] = should.delete(:orgaccess)

    context.device.dapi.update_admin(context.device.orgid, id, should)
  end

  def delete(context, id)
    context.device.dapi.revoke_admin(context.device.orgid, id)
  end

  # The order of the arrays do not matter, canonicalize them so users can specify them in any order
  # canonicalize is called after get and before set
  def canonicalize(_context, resources)
    resources.each do |r|
      r[:networks].sort_by! { |k| k['id'] } if r[:networks]
      r[:tags].sort_by! { |k| k['tag'] } if r[:tags]
    end
  end
end
