class Account
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model
  
  field :name, :type => String
  field :email, :type => String
  field :secret_token, :type => String
  field :crypted_password, :type => String
  field :role, :type => String, :default => 'user'
  field :time_zone, :type => String, :default => 'London'  
  field :has_picture, :type => Boolean
  field :picture_uid, :type => String  
  field :phone, :type => String 
  field :website, :type => String 
  field :location, :type => String 
  field :coordinates, :type => Array
    
  EnvFields.set(self)
  
  include Geocoder::Model::Mongoid
  geocoded_by :location  
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  after_validation do
    self.geocode || (self.coordinates = nil)
  end

  has_many :sign_ins, :dependent => :destroy  
  has_many :page_views, :dependent => :destroy  
  has_many :memberships, :dependent => :destroy
  has_many :membership_requests, :dependent => :destroy
  has_many :conversation_posts, :dependent => :destroy
  has_many :conversation_mutes, :dependent => :destroy
  has_many :events_as_creator, :class_name => 'Event', :inverse_of => :account, :dependent => :destroy
  has_many :wall_posts_as_creator, :class_name => 'WallPost', :inverse_of => :account, :dependent => :destroy
  has_many :spaces_as_creator, :class_name => 'Space', :inverse_of => :account, :dependent => :destroy
  
  has_many :affiliations, :dependent => :destroy
  accepts_nested_attributes_for :affiliations, allow_destroy: true, reject_if: :all_blank, autosave: false
  
  has_many :account_tagships, :dependent => :destroy
  accepts_nested_attributes_for :account_tagships, allow_destroy: true, reject_if: :all_blank
    
  attr_accessor :account_tag_ids
  before_validation :create_account_tags
  def create_account_tags
    if @account_tag_ids
      account_tagships.destroy_all
      @account_tag_ids.each { |id|
        Account.skip_callback(:validation, :before, :create_account_tags)
        account_tagships.create :account_tag_id => id   
        Account.set_callback(:validation, :before, :create_account_tags)        
      }
      @account_tag_ids = nil
    end
  end  
  
  def self.marker_color
    '3DA2E4'
  end
          
  def network    
    Account.where(:id.in => memberships.map(&:group).map(&:memberships).flatten.map(&:account_id))
  end
  
  def events
    Event.where(:id.in => memberships.map(&:group).map(&:events).flatten.map(&:id))
  end  
  
  def conversations
    Conversation.where(:id.in => memberships.map(&:group).map(&:conversations).flatten.map(&:_id))
  end
  
  def spaces
    Space.where(:id.in => memberships.map(&:group).map(&:spaces).flatten.map(&:_id))
  end  
  
  def news_summaries
    NewsSummary.where(:id.in => memberships.map(&:group).map(&:news_summaries).flatten.map(&:_id))
  end
    
  def wall_posts
    WallPost.where(:id.in => memberships.map(&:group).map(&:wall_posts).flatten.map(&:_id))
  end  
  
  def tagged_posts
    TaggedPost.where(:id.in => TaggedPostTagship.where(:account_tag_id.in => account_tagships.map(&:account_tag_id)).map(&:tagged_post_id))
  end  
    
  def public_memberships
    Membership.where(:id.in => memberships.select { |membership| !membership.group.secret? }.map(&:_id))
  end
           
  # Picture
  dragonfly_accessor :picture do
    after_assign { |picture| self.picture = picture.thumb('500x500>') }
  end
  attr_accessor :rotate_picture_by
  before_validation :rotate_picture
  def rotate_picture
    if self.picture and self.rotate_picture_by
      picture.rotate(self.rotate_picture_by)
    end
    return true
  end
    
  # Connections  
  has_many :connections, :dependent => :destroy
  accepts_nested_attributes_for :connections
                        
  attr_accessor :password, :password_confirmation 

  validates_presence_of :name, :email
  validates_presence_of :password, :if => :password_required
  validates_presence_of :password_confirmation, :if => :password_required  
  validates_presence_of :role, :time_zone # defaults
  
  validates_length_of :email, :within => 3..100
  validates_uniqueness_of :email, :case_sensitive => false
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i  
  validates_length_of :password, :within => 4..40, :if => :password_required
  validates_confirmation_of :password, :if => :password_required 
  
  index({email: 1 }, {unique: true})
  
  before_validation do
    self.website = "http://#{self.website}" if self.website and !(self.website =~ /\Ahttps?:\/\//)
  end  
    
  before_validation :set_has_picture
  def set_has_picture
    self.has_picture = (self.picture ? true : false)
    return true
  end
    
  def generate_secret_token
    update_attribute(:secret_token, ::BCrypt::Password.create(self.id)) if !self.secret_token
    self.secret_token
  end  
          
  def self.fields_for_index
    [:name, :email, :phone, :created_at]
  end
    
  def self.fields_for_form
    {
      :name => :text,
      :email => :text,
      :secret_token => :text,
      :phone => :text, 
      :website => :text,
      :picture => :image,
      :role => :select,
      :time_zone => :select,
      :password => :password,
      :password_confirmation => :password,
      :location => :text,
      :affiliations => :collection
    }.merge(EnvFields.fields(self))
  end
  
  def self.filter_options
    {
      :o => 'created_at',
      :d => 'desc'
    }    
  end
    
  def self.edit_hints
    {
      :password => 'Leave blank to keep existing password'      
    }
  end   
  
  def self.human_attribute_name(attr, options={})  
    {
      :account_tag_ids => I18n.t(:account_tagships).capitalize,
      :expertise => 'Areas of expertise',
      :password_confirmation => "Password again"
    }[attr.to_sym] || super  
  end     
           
  def self.time_zones
    ['']+ActiveSupport::TimeZone::MAPPING.keys.sort
  end  
  
  def self.roles
    ['user','admin']
  end    
  
  def admin?
    role == 'admin'
  end
  
  def self.lookup
    :name
  end  
    
  def uid
    id
  end
  
  def info
    {:email => email, :name => name}
  end
  
  def self.authenticate(email, password)
    account = find_by(email: /^#{Regexp.escape(email)}$/i) if email.present?
    account && account.has_password?(password) ? account : nil
  end
  
  before_save :encrypt_password, :if => :password_required

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end
  
  def self.generate_password(len)
    chars = ("a".."z").to_a + ("0".."9").to_a
    return Array.new(len) { chars[rand(chars.size)] }.join
  end 

  private
  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(self.password)
  end

  def password_required
    crypted_password.blank? || self.password.present?
  end  
    
end
