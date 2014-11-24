class ConversationPostReadReceipt
  include Mongoid::Document
  include Mongoid::Timestamps
   
  belongs_to :account, index: true
  belongs_to :conversation_post, index: true
  
  field :web, :type => Boolean
  
  validates_presence_of :account, :conversation_post
  validates_uniqueness_of :account, :scope => :conversation_post
        
  def self.admin_fields
    {
      :account_id => :lookup,
      :conversation_post_id => :lookup,
      :web => :check_box
    }
  end
              
end
