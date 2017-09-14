require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def todos_count(list)
    list[:todos].size
  end

  def remaining_todos_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_completed?(list)
    todos_count(list) > 0 && remaining_todos_count(list) == 0
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def sort_lists(lists)
    lists.sort_by { |list| list_completed?(list) ? 1 : 0 }
         .each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
         .each { |todo| yield todo, todos.index(todo) }
  end
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View list of todos
get '/lists/:list_id' do
  @list_id  = params[:list_id].to_i
  @list = session[:lists][@list_id ]

  erb :list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error

    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'

    redirect '/lists'
  end
end

# Render the edit list form
get '/lists/:list_id/edit' do
  @list_id  = params[:list_id].to_i
  @list = session[:lists][@list_id]

  erb :edit_list, layout: :layout
end

# Edit an existing to do list
post '/lists/:list_id' do
  new_list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error

    erb :edit_list, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = 'The list name has been updated.'

    redirect "/lists/#{@list_id }"
  end
end

# Delete a todo list
post '/lists/:list_id/delete' do
  id = params[:list_id].to_i
  session[:lists].delete_at(id)
  session[:success] = 'The list has been deleted.'

  redirect '/lists'
end

# Add a new todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error

    erb :list, layout: :layout
  else
    @list[:todos] << { name: params[:todo], completed: false }
    session[:success] = 'The todo has been added.'

    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = 'The list has been deleted.'

  redirect "/lists/#{@list_id}"
end

# Mark a todo item as complete or not complete
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  todo = @list[:todos][todo_id]
  is_completed = params[:completed] == "true"

  todo[:completed] = is_completed
  session[:success] = 'The list has been updated.'

  redirect "/lists/#{@list_id}"
end

# Mark all todos in a list as completed
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = 'All todos have been completed.'

  redirect "/lists/#{@list_id}"
end

# Return an error message if the list name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Return an error message if the todo name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo name must be between 1 and 100 characters.'
  end
end

