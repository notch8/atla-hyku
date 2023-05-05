# Generated via
#  `rails generate hyrax:work Etd`
class Etd < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = EtdIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }
  validates :creator, presence: { message: 'Your work must have a creator.' }

  property :bibliographic_citation, predicate: ::RDF::Vocab::DC.bibliographicCitation do |index|
    index.as :stored_searchable
  end
  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
