# encoding: utf-8
module Mongoid # :nodoc:
  module Relations #:nodoc:
    module Referenced #:nodoc:
      class Many < Proxy

        # Append an object to the relation, which will bind the new object
        # and save it if the base is persisted.
        #
        # Example:
        #
        # <tt>person.posts << Post.new</tt>
        #
        # Options:
        #
        # document: The document to append.
        #
        # Returns:
        #
        # The relation.
        def <<(*docs)
          docs.flatten.each do |doc|
            unless target.include?(doc)
              append(doc)
              doc.save if base.persisted?
            end
          end
        end
        alias :concat :<<
        alias :push :<<

        # Binds the base object to the inverse of the relation. This is so we
        # are referenced to the actual objects themselves and dont hit the
        # database twice when setting the relations up.
        #
        # This is called after first creating the relation, or if a new object
        # is set on the relation.
        #
        # Example:
        #
        # <tt>person.posts.bind</tt>
        def bind(building = nil)
          binding.bind
          target.map(&:save) if base.persisted? && !building?
        end

        # Builds a new document on the references many relation.
        #
        # Example:
        #
        # <tt>person.posts.build(:text => "Testing")</tt>
        #
        # Options:
        #
        # attributes:
        #
        # A hash of attributes to build the document with.
        #
        # Returns:
        #
        # The newly built document.
        def build(attributes = nil, type = nil)
          instantiated(type).tap do |doc|
            append(doc)
            doc.write_attributes(attributes)
            doc.identify
          end
        end

        # Clear the relation. Will delete the documents from the db if they are
        # already persisted.
        #
        # Example:
        #
        # <tt>relation.clear</tt>
        #
        # Returns:
        #
        # The empty relation.
        def clear
          tap { |relation| relation.unbind }
        end

        # Returns a count of the number of documents in the association that have
        # actually been persisted to the database.
        #
        # Use #size if you want the total number of documents.
        #
        # Returns:
        #
        # The total number of persisted embedded docs, as flagged by the
        # #persisted? method.
        def count
          target.select(&:persisted?).size
        end

        # Creates a new document on the references many relation. This will
        # save the document if the parent has been persisted.
        #
        # Example:
        #
        # <tt>person.posts.create(:text => "Testing")</tt>
        #
        # Options:
        #
        # attributes:
        #
        # A hash of attributes to create the document with.
        #
        # Returns:
        #
        # The newly created document.
        def create(attributes = nil)
          build(attributes).tap do |doc|
            doc.save if base.persisted?
          end
        end

        # Creates a new document on the references many relation. This will
        # save the document if the parent has been persisted and will raise an
        # error if validation fails.
        #
        # Example:
        #
        # <tt>person.posts.create!(:text => "Testing")</tt>
        #
        # Options:
        #
        # attributes:
        #
        # A hash of attributes to create the document with.
        #
        # Returns:
        #
        # The newly created document.
        def create!(attributes = nil)
          build(attributes).tap do |doc|
            doc.save! if base.persisted?
          end
        end

        # Deletes all related documents from the database given the supplied
        # conditions.
        #
        # Example:
        #
        # <tt>person.posts.delete_all(:title => "Testing")</tt>
        #
        # Options:
        #
        # conditions: A hash of conditions to limit the delete by.
        #
        # Returns:
        #
        # The number of documents deleted.
        def delete_all(conditions = nil)
          selector = (conditions || {})[:conditions] || {}
          target.delete_if { |doc| doc.matches?(selector) }
          metadata.klass.delete_all(
            :conditions => selector.merge(metadata.foreign_key => base.id)
          )
        end

        # Deletes all related documents from the database given the supplied
        # conditions.
        #
        # Example:
        #
        # <tt>person.posts.destroy_all(:title => "Testing")</tt>
        #
        # Options:
        #
        # conditions: A hash of conditions to limit the delete by.
        #
        # Returns:
        #
        # The number of documents deleted.
        def destroy_all(conditions = nil)
          selector = (conditions || {})[:conditions] || {}
          target.delete_if { |doc| doc.matches?(selector) }
          metadata.klass.destroy_all(
            :conditions => selector.merge(metadata.foreign_key => base.id)
          )
        end

        # Determine if any documents in this relation exist in the database.
        #
        # Example:
        #
        # <tt>person.posts.exists?</tt>
        #
        # Returns:
        #
        # True is persisted documents exist, false if not.
        def exists?
          count > 0
        end

        # Find the matchind document on the association, either based on id or
        # conditions.
        #
        # Example:
        #
        # <tt>person.find(ObjectID("4c52c439931a90ab29000005"))</tt>
        # <tt>person.find(:all, :conditions => { :title => "Sir" })</tt>
        # <tt>person.find(:first, :conditions => { :title => "Sir" })</tt>
        # <tt>person.find(:last, :conditions => { :title => "Sir" })</tt>
        #
        # Options:
        #
        # arg: Either an id or a type of search.
        # options: a Hash of selector arguments.
        #
        # Returns:
        #
        # The matching document or documents.
        def find(arg, options = {})
          klass = metadata.klass
          return klass.criteria.id_criteria(arg) unless arg.is_a?(Symbol)
          selector = (options[:conditions] || {}).merge(
            metadata.foreign_key => base.id
          )
          klass.find(arg, :conditions => selector)
        end

        # Find the first +Document+ given the conditions, or creates a new document
        # with the conditions that were supplied
        #
        # Example:
        #
        # <tt>person.posts.find_or_create_by(:title => "Testing")</tt>
        #
        # Options:
        #
        # attrs: A +Hash+ of attributes
        #
        # Returns:
        #
        # An existing document or newly created one.
        def find_or_create_by(attrs = {})
          find_or(:create, attrs)
        end

        # Find the first +Document+ given the conditions, or instantiates a new document
        # with the conditions that were supplied
        #
        # Example:
        #
        # <tt>person.posts.find_or_initialize_by(:title => "Test")</tt>
        #
        # Options:
        #
        # attrs: A +Hash+ of attributes
        #
        # Returns:
        #
        # An existing document or new one.
        def find_or_initialize_by(attrs = {})
          find_or(:build, attrs)
        end

        # Instantiate a new references_many relation. Will set the foreign key
        # and the base on the inverse object.
        #
        # Example:
        #
        # <tt>Referenced::Many.new(base, target, metadata)</tt>
        #
        # Options:
        #
        # base: The document this relation hangs off of.
        # target: The target [child documents] of the relation.
        # metadata: The relation's metadata
        def initialize(base, target, metadata)
          init(base, target, metadata)
        end

        # Substitutes the supplied target documents for the existing documents
        # in the relation. If the new target is nil, perform the necessary
        # deletion.
        #
        # Example:
        #
        # <tt>posts.substitute(new_name)</tt>
        #
        # Options:
        #
        # target: An array of documents to replace the target.
        #
        # Returns:
        #
        # The relation or nil.
        def substitute(target, building = nil)
          tap { target ? (@target = target.to_a; bind) : (@target = unbind) }
        end

        # Unbinds the base object to the inverse of the relation. This occurs
        # when setting a side of the relation to nil.
        #
        # Will delete the object if necessary.
        #
        # Example:
        #
        # <tt>person.posts.unbind</tt>
        def unbind
          binding.unbind
          target.each(&:delete) if base.persisted?
          []
        end

        private

        # Appends the document to the target array, updating the index on the
        # document at the same time.
        #
        # Example:
        #
        # <tt>relation.append(document)</tt>
        #
        # Options:
        #
        # document: The document to append to the target.
        def append(document)
          loaded and target.push(document)
          document.send(metadata.foreign_key_setter, base.id)
          document.send(metadata.inverse_setter(target), base)
          metadatafy(document) # and bind_one(document)
        end

        # Instantiate the binding associated with this relation.
        #
        # Example:
        #
        # <tt>binding([ address ])</tt>
        #
        # Options:
        #
        # new_target: The new documents to bind with.
        #
        # Returns:
        #
        # A binding object.
        def binding(new_target = nil)
          Bindings::Referenced::Many.new(base, new_target || target, metadata)
        end

        # Find the first object given the supplied attributes or create/initialize it.
        #
        # Example:
        #
        # <tt>person.addresses.find_or(:create, :street => "Bond")</tt>
        #
        # Options:
        #
        # method: The method name, create or new.
        # attrs: The attributes to build with
        #
        # Returns:
        #
        # A matching document or a new/created one.
        def find_or(method, attrs = {})
          find(:first, :conditions => attrs) || send(method, attrs)
        end

        def loaded
          tap do |relation|
            relation.target = target.entries if target.is_a?(Mongoid::Criteria)
          end
        end

        class << self

          # Return the builder that is responsible for generating the documents
          # that will be used by this relation.
          #
          # Example:
          #
          # <tt>Referenced::Many.builder(meta, object)</tt>
          #
          # Options:
          #
          # meta: The metadata of the relation.
          # object: A document or attributes to build with.
          #
          # Returns:
          #
          # A newly instantiated builder object.
          def builder(meta, object)
            Builders::Referenced::Many.new(meta, object)
          end


          # Returns true if the relation is an embedded one. In this case
          # always false.
          #
          # Example:
          #
          # <tt>Referenced::Many.embedded?</tt>
          #
          # Returns:
          #
          # true
          def embedded?
            false
          end

          # Returns the suffix of the foreign key field, either "_id" or "_ids".
          #
          # Example:
          #
          # <tt>Referenced::Many.foreign_key_suffix</tt>
          #
          # Returns:
          #
          # "_id"
          def foreign_key_suffix
            "_id"
          end

          # Returns the macro for this relation. Used mostly as a helper in
          # reflection.
          #
          # Example:
          #
          # <tt>Mongoid::Relations::Referenced::Many.macro</tt>
          #
          # Returns:
          #
          # <tt>:references_many</tt>
          def macro
            :references_many
          end

          # Return the nested builder that is responsible for generating the documents
          # that will be used by this relation.
          #
          # Example:
          #
          # <tt>Referenced::Nested::Many.builder(attributes, options)</tt>
          #
          # Options:
          #
          # attributes: The attributes to build with.
          # options: The options for the builder.
          #
          # Returns:
          #
          # A newly instantiated nested builder object.
          def nested_builder(metadata, attributes, options)
            Builders::Referenced::Nested::Many.new(metadata, attributes, options)
          end

          # Tells the caller if this relation is one that stores the foreign
          # key on its own objects.
          #
          # Example:
          #
          # <tt>Referenced::Many.stores_foreign_key?</tt>
          #
          # Returns:
          #
          # false
          def stores_foreign_key?
            false
          end
        end
      end
    end
  end
end