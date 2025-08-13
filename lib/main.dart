import 'dart:math';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/servicemanagement/v1.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;


final user = googleSignIn.signInSilently();

final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar',
  ],
);

class GoogleAuthClient extends http.BaseClient {

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

Future<calendar.CalendarApi?> getCalendarApi() async{

  final account = await googleSignIn.signInSilently() ?? await googleSignIn.signIn();
  if (account == null){
    return null;
  }

  final authHeaders = await account.authHeaders;
  final client = GoogleAuthClient(authHeaders);

  return calendar.CalendarApi(client);
}

Future<void> SyncTodosToCalendar(List<Todo> todos) async {

  final account = await googleSignIn.signInSilently() ?? await googleSignIn.signIn();
  if (account == null) { return null; }



  final authHeaders = await account.authHeaders;
  final client = GoogleAuthClient(authHeaders);
  final calendarApi = calendar.CalendarApi(client);

  for (var todo in todos){
    if(todo.dueDate != null){
      var event = calendar.Event(
        summary: todo.title,
        description: todo.description,
        start: calendar.EventDateTime(
          dateTime: todo.dueDate,
          timeZone: 'UTC',
        ),
        end: calendar.EventDateTime(
          dateTime: todo.dueDate!.add(Duration(hours: 1)), // Default to 1 hour duration
          timeZone: 'UTC',
        )
      );

      try{
        await calendarApi.events.insert(event, "primary");
        debugPrint("Todo '${todo.title}' synced to Google Calendar");
      }
      catch (e) {
        debugPrint("Failed to sync todo '${todo.title}' to Google Calendar: $e");
      }
    }
  } 
}

Future<GoogleSignInAccount?> signInWithGoogle() async {
   try {
    final account = await googleSignIn.signIn();
    if (account != null) {
      debugPrint("User signed in: ${account.displayName}");
    }
    return account;
  } catch (error) {
    debugPrint("Google Sign-In error: $error");
    return null;
  }
}



final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  runApp(
    
    ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _){
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: currentTheme,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.pink,
            scaffoldBackgroundColor: Colors.white,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
          ),
          darkTheme: ThemeData(
             brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primarySwatch: Colors.pink,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          ),
          home: DefaultTabController(
            length: 3,
            child: TodoHomePage(),
          ),
        );
      }
    )    
    );
}

enum Priority { low, medium, high }
enum TodoFilter { all, active, completed }


class Todo{

  String id;
  IconData icon;
  int total;
  int completed;
  String title;
  String description;
  DateTime createdAt;
  DateTime? dueDate;  
  Priority priority;
  String category;
  bool isCompleted;

  Todo({
    required this.icon,
    required this.total,
    required this.completed,
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate, 
    this.category = 'General',
    this.priority = Priority.low,
  });
      
    double get progress => total > 0 ? completed / total : 0.0;

}

Map<String, IconData> categoryIcons = {
  'General': Icons.category,
  'Work': Icons.work,
  'Personal': Icons.person,
  'Health': Icons.health_and_safety,
  'Shopping': Icons.shopping_cart,
  'Finance': Icons.account_balance_wallet,
  'Travel': Icons.travel_explore,
  'Education': Icons.school,
};

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  _TodoHomePageState createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {

  String? selectedCategory;
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
        icon: categoryIcons['travel'] ?? Icons.category,
        total: index % 5 + 1,
        completed: index % 3, // Randomly set completed count for demo
        id: 'todo_$index',
        title: 'Todo Item $index',
        description: 'Description for Todo Item $index',
        createdAt: DateTime.now().subtract(Duration(days: index)),
        dueDate: DateTime.now().add(Duration(days: index)),
        priority: Priority.values[index % Priority.values.length],
      );
    });
  }

Map<String, List<Todo>> get categoryMap{
  Map<String, List<Todo>> map ={};

  for(var todo in todos){
    map.putIfAbsent(todo.category,() => []).add(todo);
  }
  return map;
}

List<Todo> get filteredTodos{


  //List<Todo> filtered = todos;
List<Todo> filteredTodos = todos.where((todo) {
  final matchesFilter = currentFilter == TodoFilter.all
      || (currentFilter == TodoFilter.active && !todo.isCompleted)
      || (currentFilter == TodoFilter.completed && todo.isCompleted);
  final matchesCategory = selectedCategory == null || todo.category == selectedCategory;
  return matchesFilter && matchesCategory;
}).toList();

  if (searchQuery.isNotEmpty) {
    filteredTodos = filteredTodos.where((todo) => 
    todo.title.toLowerCase().contains(searchQuery.toLowerCase())||
    todo.description.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  switch (currentFilter){
    case TodoFilter.active:
      filteredTodos = filteredTodos.where((todo) => !todo.isCompleted).toList();
      break;
    case TodoFilter.completed:
      filteredTodos = filteredTodos.where((todo) => todo.isCompleted).toList();
      break;
    case TodoFilter.all:
      break;
  }

  filteredTodos.sort((a, b) {
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

  return filteredTodos;

}

int get activeTodosCount => todos.where((todo)=> !todo.isCompleted).length;
int get completedTodosCount => todos.where((todo) => todo.isCompleted).length;

Widget buildCategoryScroll(){
  final categoryData = categoryMap;
  final isDark = Theme.of(context).brightness == Brightness.dark;


  return SizedBox(
    height: 120,
    child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: categoryData.keys.length,
        separatorBuilder: (_,_) => SizedBox(width: 12),
        itemBuilder: (context, index){
          final category = categoryData.keys.elementAt(index);
          final todosInCategory = categoryData[category]!;
          final total = todosInCategory.length;
          final completed = todosInCategory.where((t) => t.isCompleted).length;
          final progress = total == 0 ? 0.0 : completed / total;

          return GestureDetector(

            onTap: (){
              setState(() {
                currentFilter = TodoFilter.all;
                selectedCategory = category;
              });
            },
            child: Container(
              width: 150,
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark? Colors.pink.withOpacity(0.1): Colors.white,
                border: Border.all(color: isDark ? Colors.pinkAccent: Colors.black.withOpacity(0.2)),

              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark?Colors.white: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark? Colors.white30: Colors.grey[300],
                    color: Colors.pinkAccent,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '$completed/$total Completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70: Colors.black54,
                    ),
                  )
                ],
              ),
            )

          );

        },
      )
  );
}


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
final isDark = Theme.of(context).brightness == Brightness.dark;

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
  leading: Builder(
    builder: (context){
      return IconButton(
        icon: CircleAvatar(
          backgroundImage: NetworkImage('https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png'),
        ),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
        tooltip: 'Menu',
      );
    }
),
),  
drawer: FutureBuilder<GoogleSignInAccount?>(
  future: signInWithGoogle(),
  builder: (context, snapshot) {
    final user = snapshot.data;
    return Drawer(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
            ),
            child: Text(
              'Welcome ${user?.displayName ?? 'User'}',
              style: GoogleFonts.poppins(
                fontSize: 24,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.login, color: isDark ? Colors.white : Colors.black),
            title: Text('Login', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () async {
              final user = await signInWithGoogle();
              if (user != null) {                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged in as ${user.displayName}'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Login failed'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.sync, color: isDark ? Colors.white : Colors.black),
            title: Text('Sync', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () async{
              await SyncTodosToCalendar(todos);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Todos synced to Google Calendar'),
                  duration: Duration(seconds: 2),
                ),
              );
              // Handle home tap
            },
          ),
          ListTile(
            leading: Icon(Icons.dark_mode_outlined, color: isDark ? Colors.white : Colors.black),
            title: Text('Theme', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              // Handle settings tap
              themeNotifier.value =
                  themeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  },
),
    body: Column(
      children: [
        Container(
          padding:  EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: isDark ?Colors.white70: Colors.black54),
                borderRadius: BorderRadius.circular(10.0),
              ),
              filled: true,
              fillColor: Colors.white10,
              hintText: 'Search Todos...',
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70: Colors.black54),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              buildCategoryScroll(),
              SizedBox(height: 12),
  ],
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
      elevation: 10,
      splashColor: Colors.deepPurpleAccent,
      child: Icon(Icons.add, size: 28),
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
        leading: Icon(Icons.priority_high, color: _getPriorityColor(todo.priority)),
        title: Text(_getPriorityText(todo.priority)),
      ),
      ListTile(
        leading: Icon(categoryIcons[todo.category] ?? Icons.category),
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
                icon: widget.todo?.icon ?? Icons.check_circle_outline,
                total: widget.todo?.total ?? 1,
                completed: widget.todo?.completed ?? 0,
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