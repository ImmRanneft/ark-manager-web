require 'dalli'
require 'hashie'
require 'base64'
require 'json'

class ArkMod < Hashie::Dash
  include Hashie::Extensions::MethodAccess
  include Hashie::Extensions::IgnoreUndeclared
  property :id, required: true
  property :version, required: true, default: Base64.encode64('Mod Not Tracked Yet').gsub!(/\n/, '')
  property :name, required: true, default: 'unknown'
  property :created_at, required: true, default: Time.now.utc.strftime('%m-%d-%Y %H:%M:%S')
  property :updated_at, required: true, default: Time.now.utc.strftime('%m-%d-%Y %H:%M:%S')
end

class Repository
  def self.register(type, repo)
    repositories[type] = repo
  end
  def self.repositories
    @repositories ||= {}
  end
  def self.for(type)
    repositories[type]
  end
end


module DalliAdapter
  class ModRepository
    def initialize
      options = { :namespace => "app_v1", :compress => true }
      @interface = Dalli::Client.new('127.0.0.1:11211', options)
    end
    def model_class
      ArkMod
    end

    def create(attributes={})
      new_record = model_class.new(attributes)
      if read_mod_list.select {|mod_info| mod_info.id == new_record.id }.count > 0
        raise 'A mod already exists with that ID! Maybe try to use the update method?'
      else
        write_mod_list(read_mod_list << new_record)
      end
    end

    def find_by(attributes={})
      attributes.each_pair do |k, v|
        return Repository.for(:mod_list).all.find {|mod| mod[k] == v}
      end
    end

    def where(attributes={})
      return_array = Array.new
      attributes.each_pair do |k, v|
        return_array += Repository.for(:mod_list).all.select {|mod| mod[k] == v}
      end
      return_array.uniq!.sort_by { |m| m.id }
    end

    def update_by(attributes={})
      read_only_mod_info = find_by(attributes)
      writable_mod_info  = find_by(attributes)
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

    def delete_by(attributes={})
      mod_info  = find_by(attributes)
      mod_list  = read_mod_list
      mod_list.delete(mod_info)
      write_mod_list(mod_list)
    end

    def all
      read_mod_list.sort_by { |m| m.id }
    end

    def dump_file(file_name)
      hash = Repository.for(:mod_list).all.map! { |ark_mod| ark_mod.to_mash.to_h }
      File.write(file_name, hash.to_json)
    end

    def load_file(file_name)
      instances = JSON.parse File.read(file_name), symbolize_names: true
      models = instances.map! {|m| model_class.new(m) }
      write_mod_list(models)
      true
    end

    private
    def read_mod_list
      @interface.get('mod_list')
    end

    def write_mod_list(data)
      @interface.set('mod_list', data)
    end
  end
end
