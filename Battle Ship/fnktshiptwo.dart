import 'dart:io';
import 'dart:math';

const int BOARD_SIZE = 10;
const List<int> SHIP_SIZES = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];

class Board {
  List<List<String>> grid;
  List<List<List<int>>> ships = [];
  int hits = 0;

  Board()
    : grid = List.generate(BOARD_SIZE, (i) => List.filled(BOARD_SIZE, '.'));

  bool isValid(int row, int col) =>
      row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE;

  bool canPlace(int size, int row, int col, bool vertical) {
    for (int i = 0; i < size; i++) {
      int r = vertical ? row + i : row;
      int c = vertical ? col : col + i;
      if (!isValid(r, c) || grid[r][c] != '.') return false;
      for (int dr = -1; dr <= 1; dr++)
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          int nr = r + dr, nc = c + dc;
          if (isValid(nr, nc) && grid[nr][nc] == 'S') return false;
        }
    }
    return true;
  }

  void placeShip(int size, int row, int col, bool vertical) {
    List<List<int>> positions = [];
    for (int i = 0; i < size; i++) {
      int r = vertical ? row + i : row;
      int c = vertical ? col : col + i;
      grid[r][c] = 'S';
      positions.add([r, c]);
    }
    ships.add(positions);
  }

  void placeRandom() {
    Random rand = Random();
    for (int size in SHIP_SIZES) {
      bool placed = false;
      while (!placed) {
        int maxDim = BOARD_SIZE - size + 1;
        int row = rand.nextInt(maxDim);
        int col = rand.nextInt(maxDim);
        bool vertical = rand.nextBool();
        if (canPlace(size, row, col, vertical)) {
          placeShip(size, row, col, vertical);
          placed = true;
        }
      }
    }
  }

  String shoot(int row, int col) {
    if (!isValid(row, col)) return 'OOB';
    String cell = grid[row][col];
    if (cell == 'X' || cell == 'M') return 'ALR';
    if (cell == 'S') {
      grid[row][col] = 'X';
      hits++;
      _checkSunk(row, col);
      return 'HIT';
    } else {
      grid[row][col] = 'M';
      return 'MISS';
    }
  }

  void _checkSunk(int row, int col) {
    for (List<List<int>> ship in ships) {
      if (ship.any((p) => p[0] == row && p[1] == col) &&
          ship.every((p) => grid[p[0]][p[1]] == 'X')) {
        for (var p in ship) markAround(p[0], p[1]);
      }
    }
  }

  void markAround(int row, int col) {
    for (int dr = -1; dr <= 1; dr++)
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = row + dr, nc = col + dc;
        if (isValid(nr, nc) && grid[nr][nc] == '.') grid[nr][nc] = '~';
      }
  }

  bool isWin() => hits >= 20;

  void display({bool showShips = false}) {
    print('  ${List.generate(BOARD_SIZE, (i) => i + 1).join(' ')}');
    for (int i = 0; i < BOARD_SIZE; i++) {
      String rowLabel = String.fromCharCode(65 + i);
      print(
        '$rowLabel ${grid[i].map((cell) {
          if (showShips && cell == 'S') return 'S';
          return cell == 'X'
              ? 'X'
              : cell == 'M'
              ? 'M'
              : cell == '~'
              ? '~'
              : '.';
        }).join(' ')}',
      );
    }
  }
}

abstract class Player {
  Board board = Board();
  String name;
  Player(this.name);

  void placeShips() => board.placeRandom();

  String makeShot(Board opponent) => 'MISS';
}

class Human extends Player {
  Human(String n) : super(n);

  @override
  void placeShips() {
    print('$name, "r" для случайной, иначе ручная.');
    var input = stdin.readLineSync()?.toLowerCase();
    if (input != 'r')
      _manualPlace();
    else
      board.placeRandom();
  }

  void _manualPlace() {
    for (int size in SHIP_SIZES) {
      bool placed = false;
      while (!placed) {
        print('Корабль $size: напр. A1 h или A1 v');
        var line = stdin.readLineSync()?.split(' ');
        if (line == null || line.length < 3) {
          print('Неверно!');
          continue;
        }
        var pos = _parsePos(line[0]);
        if (pos == null ||
            !board.canPlace(size, pos[0], pos[1], line[2] == 'v')) {
          print('Неверная позиция!');
          continue;
        }
        board.placeShip(size, pos[0], pos[1], line[2] == 'v');
        placed = true;
      }
    }
  }

  List<int>? _parsePos(String s) {
    if (s.length < 2) return null;
    int col = s.codeUnitAt(0) - 65;
    int row = int.tryParse(s.substring(1)) ?? 0 - 1;
    return board.isValid(row, col) ? [row, col] : null;
  }

  @override
  String makeShot(Board opponent) {
    while (true) {
      print('$name, выстрел: напр. A1');
      var input = stdin.readLineSync();
      var pos = _parsePos(input ?? '');
      if (pos != null) return opponent.shoot(pos[0], pos[1]);
      print('Неверно!');
    }
  }
}

class AI extends Player {
  List<List<int>> shots = [];
  List<int>? lastHit;

  AI(String n) : super(n) {
    for (int r = 0; r < BOARD_SIZE; r++)
      for (int c = 0; c < BOARD_SIZE; c++) shots.add([r, c]);
  }

  @override
  String makeShot(Board opponent) {
    List<List<int>> candidates = [];
    if (lastHit != null) {
      int r = lastHit![0], c = lastHit![1];
      for (int dr = -1; dr <= 1; dr++)
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          int nr = r + dr, nc = c + dc;
          if (opponent.isValid(nr, nc) &&
              opponent.grid[nr][nc] == '.' &&
              shots.any((s) => s[0] == nr && s[1] == nc))
            candidates.add([nr, nc]);
        }
      if (candidates.isEmpty) lastHit = null;
    }
    if (candidates.isEmpty)
      candidates = shots
          .where((s) => opponent.grid[s[0]][s[1]] == '.')
          .toList();
    if (candidates.isEmpty) return 'ALR';

    Random rand = Random();
    var shot = candidates[rand.nextInt(candidates.length)];
    shots.remove(shot);
    String res = opponent.shoot(shot[0], shot[1]);
    if (res == 'HIT') lastHit = shot;
    return res;
  }
}

class Game {
  Player p1, p2;
  int turn = 1;
  List<String> log = [];

  Game(this.p1, this.p2);

  void run() {
    print('Морской бой! Режим: 1=против ИИ, 2=2 игрока');
    var mode = stdin.readLineSync();
    if (mode == '1') p2 = AI('ИИ');
    p1.placeShips();
    p2.placeShips();
    while (true) {
      var curr = turn == 1 ? p1 : p2;
      var opp = turn == 1 ? p2 : p1;
      print('\nХод ${curr.name}');
      curr.board.display(showShips: curr is Human);
      print('Поле противника:');
      opp.board.display();
      var res = curr.makeShot(opp.board);
      var msg =
          {
            'HIT': 'Попадание!',
            'MISS': 'Промах!',
            'ALR': 'Уже стреляли!',
            'OOB': 'Вне поля!',
          }[res] ??
          'Ошибка';
      log.add('${curr.name}: $msg');
      print(msg);
      if (opp.board.isWin()) {
        print('${curr.name} победил!');
        _end();
        return;
      }
      turn = 3 - turn;
    }
  }

  void _end() {
    print('Счёт: ${p1.name} ${p1.board.hits} - ${p2.name} ${p2.board.hits}');
    print('Лог: ${log.join('; ')}');
    print('Играть снова? д/н');
    if (stdin.readLineSync()?.toLowerCase() == 'д') {
      p1.board = Board();
      p2.board = Board();
      log.clear();
      turn = 1;
      run();
    }
  }
}

void main() {
  var p1 = Human('Игрок');
  var game = Game(p1, Human('Игрок2'));
  game.run();
}
