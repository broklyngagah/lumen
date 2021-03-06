Lumen::App.controllers do
  
  get '/analytics' do
    redirect '/analytics/cumulative_totals'
  end

  get '/analytics/cumulative_totals' do
    site_admins_only!      
    @models = [ConversationPost, Account, Event, PageView].select { |model| model.count > 0 }
    @collections = @models.map { |model| model.order_by(:created_at.asc) }            
    erb :'analytics/analytics'
  end

  get '/groups/:slug/analytics' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!      
    @collection_names = [:conversation_posts, :memberships, :events].select { |collection_name| @group.send(collection_name).count > 0 }      
    @collections = @collection_names.map { |collection_name| @group.send(collection_name).order_by(:created_at.asc) }      
    erb :'analytics/analytics'
  end 
  
  get '/analytics/sign_ins' do
    site_admins_only!  
    erb :'analytics/sign_ins'    
  end  
  
  get '/analytics/page_views' do
    site_admins_only!  
    erb :'analytics/page_views'    
  end
  
end