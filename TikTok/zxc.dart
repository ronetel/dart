import 'dart:io';
import 'dart:math';

class TikTok {
  late List<List<String>> board;
  late int size;
  String currentPlayer = 'X';
  bool againstRobot = false;
  bool gameActive = true;

  void initializeGame(int boardSize, bool vsRobot) {
    size = boardSize;
    board = List.generate(size, (_) => List.filled(size, ' '));
    againstRobot = vsRobot;
    gameActive = true;
    currentPlayer = Random().nextBool() ? 'X' : 'O';

    print('\n=== НОВАЯ ИГРА ===');
    print('Поле: $size x $size | Первый ход: $currentPlayer');
    print(againstRobot ? 'Режим: против робота' : 'Режим: два игрока');
    if (againstRobot && currentPlayer == 'O') print('Робот ходит первым!');
  }

  void displayBoard() {
    print('\n' + '┌───' * size + '┐');
    for (var row in board) {
      print('│ ${row.join(' │ ')} │');
      print('├───' * size + '┤');
    }
    print('└───' * size + '┘');
  }

  bool makeMove(int row, int col) {
    if (row < 1 || row > size || col < 1 || col > size) {
      print('Координаты от 1 до $size!');
      return false;
    }
    if (board[row - 1][col - 1] != ' ') {
      print('Клетка занята!');
      return false;
    }
    board[row - 1][col - 1] = currentPlayer;
    return true;
  }

  void robotMove() {
    print('Робот думает...');
    sleep(Duration(milliseconds: 800));

    var emptyCells = <Point>[];
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (board[i][j] == ' ') emptyCells.add(Point(i, j));
      }
    }
    if (emptyCells.isNotEmpty) {
      var move = emptyCells[Random().nextInt(emptyCells.length)];
      board[move.x][move.y] = currentPlayer;
    }
  }

  bool checkWinner() {
    for (int i = 0; i < size; i++) {
      if (board[i].every((cell) => cell == currentPlayer)) return true;
      if (board.every((row) => row[i] == currentPlayer)) return true;
    }
    bool diag1 = true, diag2 = true;
    for (int i = 0; i < size; i++) {
      if (board[i][i] != currentPlayer) diag1 = false;
      if (board[i][size - 1 - i] != currentPlayer) diag2 = false;
    }
    return diag1 || diag2;
  }

  bool checkDraw() {
    return board.every((row) => row.every((cell) => cell != ' '));
  }

  void switchPlayer() {
    currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
  }

  void playGame() {
    while (gameActive) {
      displayBoard();

      if (againstRobot && currentPlayer == 'O') {
        robotMove();
      } else {
        while (true) {
          print('\nИгрок $currentPlayer, ваш ход!');
          try {
            stdout.write('Строка (1-$size): ');
            int row = int.parse(stdin.readLineSync()!);
            stdout.write('Столбец (1-$size): ');
            int col = int.parse(stdin.readLineSync()!);

            if (makeMove(row, col)) break;
          } catch (_) {
            print('Введите числа!');
          }
        }
      }

      if (checkWinner()) {
        displayBoard();
        print(
          againstRobot && currentPlayer == 'O'
              ? '\n🤖 Робот победил!'
              : '\n🎉 Игрок $currentPlayer победил!',
        );
        gameActive = false;
      } else if (checkDraw()) {
        displayBoard();
        print('\n🤝 Ничья!');
        gameActive = false;
      } else {
        switchPlayer();
      }
    }
  }
}

class Point {
  final int x, y;
  Point(this.x, this.y);
}

void main() {
  var game = TikTok();

  while (true) {
    print('\n=== КРЕСТИКИ-НОЛИКИ ===');
    print('1 - Два игрока\n2 - Против робота');
    stdout.write('Выбор: ');
    var mode = stdin.readLineSync();
    bool vsRobot = mode == '2';

    int size = 3;
    while (true) {
      stdout.write('Размер поля (3-10): ');
      try {
        size = int.parse(stdin.readLineSync()!);
        if (size >= 3 && size <= 10) break;
        print('От 3 до 10!');
      } catch (_) {
        print('Введите число!');
      }
    }

    game.initializeGame(size, vsRobot);
    game.playGame();

    stdout.write('\nСыграть еще? (y/n): ');
    if (stdin.readLineSync()?.toLowerCase() != 'y') break;
  }
  print('До свидания!');
}
