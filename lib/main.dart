import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

void main() {
  
  runApp(TodoApp());
}


enum Priority { low, medium, high }
enum TodoFilter { all, active, completed }

class Todo{

  String id;
  String title;
  String description;
  DateTime createdAt;
  DateTime? dueDate;  
  Priority priority;
  String category;
  bool isCompleted;

  Todo({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate, 
    this.category = 'General',
    this.priority = Priority.low,
  });
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  _TodoHomePageState createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {

  List<Todo> todos = [];
  TodoFilter currentFilter = TodoFilter.all;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState(){
    super.initState();
    _loopsampleData();
  }

  void _loopsampleData() {
    todos = List.generate(10, (index) {
      return Todo(
        id: 'todo_$index',
        title: 'Todo Item $index',
        description: 'Description for Todo Item $index',
        createdAt: DateTime.now().subtract(Duration(days: index)),
        dueDate: DateTime.now().add(Duration(days: index)),
        priority: Priority.values[index % Priority.values.length],
      );
    });
  }

List<Todo> get filteredTodos{
  List<Todo> filtered = todos;

  if (searchQuery.isNotEmpty) {
    filtered = filtered.where((todo) => 
    todo.title.toLowerCase().contains(searchQuery.toLowerCase())||
    todo.description.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  switch (currentFilter){
    case TodoFilter.active:
      filtered = filtered.where((todo) => !todo.isCompleted).toList();
      break;
    case TodoFilter.completed:
      filtered = filtered.where((todo) => todo.isCompleted).toList();
      break;
    case TodoFilter.all:
      break;
  }

  filtered.sort((a, b) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1; // Completed todos go to the end
    } 
    int priorityComparison = b.priority.index.compareTo(a.priority.index);
    if (priorityComparison != 0) {
      return priorityComparison; // Higher priority first
    }
    if (a.dueDate != null && b.dueDate != null){
      return a.dueDate!.compareTo(b.dueDate!);
    }
    return b.createdAt.compareTo(a.createdAt); // Newer todos first
  });

  return filtered;

}

int get activeTodosCount => todos.where((todo)=> !todo.isCompleted).length;
int get completedTodosCount => todos.where((todo) => todo.isCompleted).length;


void _addTodo(Todo todo) {

  setState(() {
    todos.add(todo);
  });

}

void _toggleTodo(String id){

  setState(() {
    final index = todos.indexWhere((todo) => todo.id == id);
    if (index >= 0){
      todos[index].isCompleted = !todos[index].isCompleted;
    }
  });
  HapticFeedback.lightImpact();
}

void _deleteTodo(String id) {
  setState(() {
    todos.removeWhere((todo) => todo.id == id);
  });
  HapticFeedback.mediumImpact();
}

void _editTodo(Todo updatedTodo) {
  setState(() {
    final index = todos.indexWhere((todo) => todo.id == updatedTodo.id);
    if (index >= 0) {
      todos[index] = updatedTodo;
    }
  });
}

void _clearCompleted() {
  setState(() {
    todos.removeWhere((todo) => todo.isCompleted);
  });
}

Color _getPriorityColor(Priority priority) {

  switch (priority) {
    case Priority.low:
      return Colors.green;
    case Priority.medium:
      return Colors.orange;
    case Priority.high:
      return Colors.red;
  }
}

String _getPriorityText(Priority priority) {
  switch (priority) {
    case Priority.low:
      return 'Low';
    case Priority.medium:
      return 'Medium';
    case Priority.high:
      return 'High';
  }
}

@override
Widget build(BuildContext context) {

  return Scaffold(
     appBar: AppBar(
  elevation: 4,
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.deepPurpleAccent, Colors.pinkAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )
      )
      
  ),
  title: Text(
    'My Tasks',
  style: GoogleFonts.poppins(
    fontSize: 22,
  ),
  ),
  actions: [
    IconButton(
      icon: Icon(Icons.clear_all),
      onPressed: completedTodosCount > 0 ? _clearCompleted : null,
      tooltip: 'Clear Completed',
    ),
  ],
),
    body: Column(
      children: [
        Container(
          padding:  EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              hintText: 'Search Todos...',
              prefixIcon: Icon(Icons.search, color: Colors.white70),
              suffixIcon: searchQuery.isNotEmpty
                ?IconButton(
                icon: Icon(Icons.clear, color: Colors.white70,),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    searchQuery = '';
                  });
                },
              )
              : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
        ),
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                   color: Colors.pinkAccent.withOpacity(0.3),
                ),
                controller: DefaultTabController.of(context),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'All (${todos.length})'),
                  Tab(text: 'Active ($activeTodosCount)'),
                  Tab(text: 'Completed ($completedTodosCount)'),
                ],
                onTap: (index) {
                  setState(() {
                    currentFilter = TodoFilter.values[index];
                  });
                },
              )),
            ],
          ),
        ),
        Expanded(
          child: filteredTodos.isEmpty
              ?Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      searchQuery.isNotEmpty
                          ? 'No todos found'
                          : currentFilter == TodoFilter.active
                            ? 'No active todos'
                            : currentFilter == TodoFilter.completed
                              ? 'No completed todos'
                              : 'No todos available',

                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
              :ListView.builder(
                itemCount: filteredTodos.length,
                itemBuilder: (context, index){
                  final todo = filteredTodos[index];
                  return Dismissible(
                    key: Key(todo.id), 
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20.0),
                      color: Colors.red,
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction){
                      _deleteTodo(todo.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Todo Deleted'),
                          duration: Duration(seconds: 2),
                        ),
                        );
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.deepPurpleAccent.withOpacity(0.2),
          Colors.pinkAccent.withOpacity(0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
                      child: ListTile(
                        leading: Checkbox(
                          shape: CircleBorder(),
                          value: todo.isCompleted,
                          onChanged: (bool? value){
                            _toggleTodo(todo.id);
                          },
                        ),
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                            color: todo.isCompleted ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (todo.description.isNotEmpty)
                              Text(
                                todo.description,
                                style: TextStyle(
                                  color: todo.isCompleted ? Colors.grey : Colors.grey[600]
                                  ),
                                ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(todo.priority),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _getPriorityText(todo.priority),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                todo.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if(todo.dueDate != null) ...[
                                SizedBox(width: 8),
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: todo.dueDate!.isBefore(DateTime.now()) ? Colors.red : Colors.grey[600],
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '${todo.dueDate!.day}/${todo.dueDate!.month}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: todo.dueDate!.isBefore(DateTime.now()) ? Colors.red : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: (){
                                  _showEditDialog(todo);
                                },
                              ),
                              onTap: (){
                                _showTodoDetails(todo);
                              },
                      ),
                    ),
                    ),
                  ); 
                },
              ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: (){
        _showAddDialog();
      },
      tooltip: 'Add Todo',
      backgroundColor: Colors.pinkAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Icon(Icons.add, size: 28),
      elevation: 10,
      splashColor: Colors.deepPurpleAccent,
    ),
  );
}

void _showAddDialog() {
  showDialog(
    context: context, 
    builder: (context) => AddEditTodoDialog(
      onSave: _addTodo,
    )
  );
}

void _showEditDialog(Todo todo){
  showDialog(
    context: context, 
    builder: (context) => AddEditTodoDialog(
      todo: todo,
      onSave: _editTodo,
    )
  );

}

void _showTodoDetails(Todo todo){
  showDialog(

    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Color(0xFF2C2C54),
  title: Row(
    children: [
      Icon(Icons.task, color: Colors.pinkAccent),
      SizedBox(width: 8),
      Text(todo.title),
    ],
  ),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (todo.description.isNotEmpty)
        ListTile(
          leading: Icon(Icons.description),
          title: Text(todo.description),
        ),
      ListTile(
        leading: Icon(Icons.priority_high),
        title: Text(_getPriorityText(todo.priority)),
      ),
      ListTile(
        leading: Icon(Icons.category),
        title: Text(todo.category),
      ),
      ListTile(
        leading: Icon(Icons.date_range),
        title: Text('${todo.createdAt.day}/${todo.createdAt.month}/${todo.createdAt.year}'),
      ),
      if (todo.dueDate != null)
        ListTile(
          leading: Icon(Icons.schedule),
          title: Text('${todo.dueDate!.day}/${todo.dueDate!.month}/${todo.dueDate!.year}'),
        ),
    ],
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('Close'),
    ),
  ],
)
  );
}

}

class AddEditTodoDialog extends StatefulWidget{
  final Todo? todo;
  final Function(Todo) onSave;

  const AddEditTodoDialog({super.key, this.todo, required this.onSave});

  @override

  _AddEditTodoDialogState createState() => _AddEditTodoDialogState();

}

class _AddEditTodoDialogState extends State<AddEditTodoDialog>{

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late Priority _priority;
  late String _category;
  DateTime? _dueDate;



  final List<String> _categories = [
    'General',
    'Work',
    'Personal',
    'Health',
    'Shopping',
    'Finance',
    'Travel',
    'Education',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descriptionController = TextEditingController(text: widget.todo?.description ?? '');
    _priority = widget.todo?.priority ?? Priority.low;
    _category = widget.todo?.category ?? 'General';
    _dueDate = widget.todo?.dueDate;
  }

  @override
  Widget build(BuildContext context){
    return AlertDialog(

      title: Text(widget.todo == null ? 'Add Todo':'Edit Todo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<Priority>(
              value: _priority,
              decoration: InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: Priority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(_getPriorityText(priority)),
                );
              }).toList(),
              onChanged: (Priority? value) {
                setState(() {
                  _priority = value!;
                });
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  _category = value!;
                });
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(_dueDate == null ? 'no Due Date' : 'Due Date: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                  ),
                ),
                TextButton(
                  onPressed: () async  {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if(date != null){
                      setState(() {
                        _dueDate = date;
                      });
                    }
                  },
                  child: Text('Select Date'),
                ),
                if( _dueDate != null)
                TextButton(
                  onPressed: (){
                    setState(() {
                      _dueDate = null;
                    });
                  },
                  child: Text('Clear Date'),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(

          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(

          onPressed: (){
            if(_titleController.text.isNotEmpty){
              final todo = Todo(
                id: widget.todo?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: _titleController.text,
                description: _descriptionController.text,
                priority: _priority,
                category: _category,
                dueDate: _dueDate,
                createdAt: widget.todo?.createdAt ?? DateTime.now(),
                isCompleted: widget.todo?.isCompleted ?? false,
              );
              widget.onSave(todo);
              Navigator.pop(context);
            }
            },
            child: Text(widget.todo == null ? 'Add Todo' : 'Save Changes'),
            ),
      ],
    );
  }

String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
    }
  }
}

// Wrap the TodoHomePage with DefaultTabController
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Todo App',
      themeMode: ThemeMode.dark,
       darkTheme: ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Color(0xFF121212),
    cardColor: Colors.grey[900],
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    primaryColor: Colors.deepPurpleAccent,
    appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1F1F1F),
    elevation: 0,
  ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.pinkAccent,
    ),
  ),
  home: DefaultTabController(
    length: 3,
    child: TodoHomePage(),
  ),
    );
  }
}