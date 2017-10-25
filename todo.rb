require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
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
  end

  def sort_todos(todos)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
  end
end

# Return an error message if the list name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Return an error message if the todo name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo name must be between 1 and 100 characters.'
  end
end

# Load a list. Show error and redirect if the list does not exist.
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = 'That list does not exist.'
  redirect '/lists'
  halt
end

class SessionPersistence

  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(id, list_name)
    list = find_list(id)
    list[:name] = list_name
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    id = next_id(list[:todos])
    list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = new_status
  end

  def mark_all_todos_as_completed(list_id)
    list = find_list(list_id)
    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  private

  def next_id(collection)
    max = collection.map { |item| item[:id] }.max || 0
    max + 1
  end
end

before do
  @storage = SessionPersistence.new(session)
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View list of todos
get '/lists/:list_id' do
  @list_id  = params[:list_id].to_i
  @list = load_list(@list_id)
  @list_name = @list[:name]
  @todos = @list[:todos]

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
    @storage.create_new_list(list_name)

    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Render the edit list form
get '/lists/:list_id/edit' do
  @list_id  = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :edit_list, layout: :layout
end

# Update an existing to do list
post '/lists/:list_id' do
  new_list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error

    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, new_list_name)
    session[:success] = 'The list name has been updated.'

    redirect "/lists/#{@list_id }"
  end
end

# Delete a todo list
post '/lists/:list_id/delete' do
  id = params[:list_id].to_i
  @storage.delete_list(id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists" # status 200
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a new todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error

    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
    session[:success] = 'The todo has been added.'

    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  
  @storage.delete_todo_from_list(@list_id, todo_id)

  # In env, keys are standardized with capitalized and prepended
  # with "HTTP". This gets the "X-Requested-With" header.
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 # Success but no content
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Mark a todo item as complete or not complete
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  @storage.update_todo_status(@list_id, todo_id, is_completed)
  
  session[:success] = 'The list has been updated.'
  redirect "/lists/#{@list_id}"
end

# Mark all todos in a list as completed
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_as_completed(@list_id)
  
  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
