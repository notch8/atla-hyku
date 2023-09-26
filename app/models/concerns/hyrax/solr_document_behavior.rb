# frozen_string_literal: true

# This code is copied from https://github.com/samvera/hyrax/pull/6241 to solve https://github.com/scientist-softserv/atla-hyku/issues/121
# The copied code has not been included in a release yet. At the time of this writing, September 26, 2023, it is in hyrax main. The latest release is `hyrax-v4.0.0`.
# This app is currently using hyrax-v3.5.0. However, since the changes being brought in are coming from hyrax main, I'm including the
# entire files instead of writing decorators.

module Hyrax
  ##
  # @api public
  #
  # Hyrax extensions for +Blacklight+'s generated +SolrDocument+.
  #
  # @example using with +Blacklight::Solr::Document+
  #   class SolrDocument
  #     include Blacklight::Solr::Document
  #     include Hyrax::SolrDocumentBehavior
  #   end
  #
  # @see https://github.com/projectblacklight/blacklight/wiki/Understanding-Rails-and-Blacklight#models
  module SolrDocumentBehavior
    ModelWrapper = ActiveFedoraDummyModel # alias for backward compatibility

    extend ActiveSupport::Concern
    include Hydra::Works::MimeTypes
    include Hyrax::Permissions::Readable
    include Hyrax::SolrDocument::Export
    include Hyrax::SolrDocument::Characterization
    include Hyrax::SolrDocument::Metadata

    # Add a schema.org itemtype
    def itemtype
      types = resource_type || []
      ResourceTypesService.microdata_type(types.first)
    end

    def title_or_label
      return label if title.blank?
      title.join(', ')
    end

    def to_param
      id
    end

    def to_s # rubocop:disable Rails/Delegate
      title_or_label.to_s
    end

    ##
    # Offer the source model to Rails for some of the Rails methods (e.g. link_to).
    #
    # @example
    #   link_to '...', SolrDocument(:id => 'bXXXXXX5').new => <a href="/dams_object/bXXXXXX5">...</a>
    def to_model
      @model ||= ActiveFedoraDummyModel.new(hydra_model, id)
    end

    ##
    # @return [Boolean]
    def collection?
      hydra_model == Hyrax.config.collection_class
    end

    ##
    # @return [Boolean]
    def file_set?
      hydra_model == ::FileSet || hydra_model == Hyrax::FileSet
    end

    ##
    # @return [Boolean]
    def admin_set?
      hydra_model == Hyrax.config.admin_set_class
    end

    ##
    # @return [Boolean]
    def work?
      Hyrax.config.curation_concerns.include? hydra_model
    end

    # Method to return the model
    def hydra_model(classifier: nil)
      first('has_model_ssim')&.safe_constantize ||
        model_classifier(classifier).classifier(self).best_model
    end

    def depositor(default = '')
      val = first("depositor_tesim")
      val.presence || default
    end

    def creator
      solr_term = hydra_model == AdminSet ? "creator_ssim" : "creator_tesim"
      fetch(solr_term, [])
    end

    def visibility
      @visibility ||= if embargo_enforced?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_EMBARGO
                      elsif lease_enforced?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_LEASE
                      elsif public?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
                      elsif registered?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
                      else
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
                      end
    end

    def collection_type_gid
      first(Hyrax.config.collection_type_index_field)
    end

    def embargo_enforced?
      return false if embargo_release_date.blank?

      indexed_embargo_visibility = first('visibility_during_embargo_ssim')
      # if we didn't index an embargo visibility, assume the release date means
      # it's enforced
      return true if indexed_embargo_visibility.blank?

      # if the visibility and the visibility during embargo are the same, we're
      # enforcing the embargo
      self['visibility_ssi'] == indexed_embargo_visibility
    end

    def lease_enforced?
      lease_expiration_date.present?
    end

    private

    def model_classifier(classifier)
      classifier || ActiveFedora.model_mapper
    end
  end
end