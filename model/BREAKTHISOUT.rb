require 'dalli'
require 'hashie'
require 'base64'
options = { :namespace => "app_v1", :compress => true }
CACHE = Dalli::Client.new('127.0.0.1:11211', options)
CACHE.flush
CACHE.set('mod_list', Array.new) if CACHE.get('mod_list').nil?
class ArkMod < Hashie::Dash
  include Hashie::Extensions::MethodAccess
  include Hashie::Extensions::IgnoreUndeclared
  property :id, required: true
  property :version, required: true, default: Base64.encode64('Mod Not Tracked Yet').gsub!(/\n/, '')
  property :name, required: true, default: 'unknown'
  property :created_at, required: true, default: Time.now.utc.strftime('%m-%d-%Y %H:%M:%S')
  property :updated_at, required: true, default: Time.now.utc.strftime('%m-%d-%Y %H:%M:%S')
end

class ModList
  def self.read_mod_list
    CACHE.get('mod_list')
  end

  def self.write_mod_list(data)
    CACHE.set('mod_list', data)
  end

  def self.create(mod_id, mod_name='')
    mod_information = ArkMod.new(
        id: mod_id,
        name: mod_name
    )

    if read_mod_list.select {|mod_info| mod_info.id == mod_information.id }.count > 0
      raise 'A mod already exists with that ID! Maybe try to use the update method?'
    else
      write_mod_list(read_mod_list << mod_information)
    end
  end

  def self.find_by_id(mod_id)
    potential =  read_mod_list.select {|mod_info| mod_info.id == mod_id }
    if potential.count != 1
      raise "The mod you were looking for was not found! ID that was used in search: #{mod_id}"
    end
    potential.first
  end
  
  def self.update_by_id(mod_id)
    read_only_mod_info = find_by_id(mod_id)
    writable_mod_info  = find_by_id(mod_id)
    mod_list  = read_mod_list
    mod_index = mod_list.index(read_only_mod_info)
    yield(writable_mod_info)

    if writable_mod_info.id != read_only_mod_info.id || writable_mod_info.created_at != read_only_mod_info.created_at
      raise 'The mods ID and created at attributes are read only and should never be modified!'
    end

    writable_mod_info.updated_at = Time.now.utc.strftime('%m-%d-%Y %H:%M:%S')
    mod_list[mod_index] = writable_mod_info
    write_mod_list(mod_list)
  end

  def self.delete_by_id(mod_id)
    mod_info  = find_by_id(mod_id)
    mod_list  = read_mod_list
    write_mod_list(mod_list[mod_list.index(mod_info)])
  end

  def self.all
    read_mod_list
  end
end


25.times do |i|
  ModList.create(rand(11111111..99999999), "blanket #{i}")
end

ModList.create(10000000, 'og')
ModList.create(10000001, 'og2')


ModList.update_by_id(10000000) do |mod|
  mod.version = 'modified'
end

puts ModList.find_by_id(199991)

