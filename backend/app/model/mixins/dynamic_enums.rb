module DynamicEnums

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def uses_enums(*definitions)
      definitions.each do |definition|
        Enumeration.register_enumeration_user(definition, self)
      end

      self.instance_eval do

        definitions.each do |definition|
          property = definition[:property].intern
          property_id = "#{definition[:property]}_id".intern

          define_method("#{property}=".intern) do |value|

            if value
              enum_value_id = BackendEnumSource.id_for_value(definition[:uses_enum], value)

              if !enum_value_id && value == 'other_unmapped' && AppConfig[:allow_other_unmapped]
                # Ensure this value exists for this enumeration
                enum = Enumeration[:name => definition[:uses_enum]]
                enum_value_id = EnumerationValue.create(:enumeration_id => enum.id, :value => 'other_unmapped').id
              end

              raise "Invalid value: #{value}" if !enum_value_id

              self[property_id] = enum_value_id
            else
              self[property_id] = nil
            end
          end


          define_method("#{property}".intern) do
            if self[property_id]
              enum = EnumerationValue[self[property_id]] or raise "Couldn't find enum for #{self[property_id]}"
              enum[:value]
            else
              nil
            end
          end
        end


        define_method(:values) do
          values = super
          values = values.clone

          definitions.each do |definition|
            property = definition[:property].intern
            values[property] = self.send(property)
          end

          values
        end

      end
    end
  end
end


require_relative '../enumeration'
