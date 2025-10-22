import 'dart:io';
import 'dart:math';

const int BOARD_SIZE = 10;
const List<int> SHIP_SIZES = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];

class GameStats {
  String playerName;
  int hits = 0;
  int misses = 0;
  int shipsDestroyed = 0;
  int shipsLost = 0;
  int shipsRemaining = 10;
  int totalShots = 0;
  DateTime? gameStart;
  DateTime? gameEnd;

  GameStats(this.playerName);

  double get accuracy => totalShots > 0 ? (hits / totalShots * 100) : 0;
  Duration get gameDuration => gameEnd != null && gameStart != null
      ? gameEnd!.difference(gameStart!)
      : Duration.zero;

  void startGame() {
    gameStart = DateTime.now();
  }

  void endGame() {
    gameEnd = DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'playerName': playerName,
      'hits': hits,
      'misses': misses,
      'shipsDestroyed': shipsDestroyed,
      'shipsLost': shipsLost,
      'shipsRemaining': shipsRemaining,
      'totalShots': totalShots,
      'accuracy': accuracy.toStringAsFixed(2),
      'gameDuration':
          '${gameDuration.inMinutes} мин ${gameDuration.inSeconds % 60} сек',
      'gameDate': gameStart?.toIso8601String() ?? '',
    };
  }

  @override
  String toString() {
    return '''
Игрок: $playerName
Попадания: $hits
Промахи: $misses
Уничтожено кораблей противника: $shipsDestroyed
Потеряно кораблей: $shipsLost
Осталось кораблей: $shipsRemaining
Всего выстрелов: $totalShots
Точность: ${accuracy.toStringAsFixed(2)}%
Длительность игры: ${gameDuration.inMinutes} мин ${gameDuration.inSeconds % 60} сек
''';
  }
}

class Board {
  List<List<String>> grid;
  List<List<List<int>>> ships = [];
  int hits = 0;
  int shipsSunk = 0;

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
      if (ship.any((p) => p[0] == row && p[1] == col)) {
        bool isSunk = ship.every((p) => grid[p[0]][p[1]] == 'X');
        if (isSunk) {
          shipsSunk++;
          for (var p in ship) markAround(p[0], p[1]);
        }
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

  bool isWin() => shipsSunk >= SHIP_SIZES.length;

  int get shipsRemaining => SHIP_SIZES.length - shipsSunk;

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
  GameStats stats;
  Player(this.name) : stats = GameStats(name);

  void placeShips() => board.placeRandom();

  String makeShot(Board opponent) => 'MISS';

  void updateStats(String shotResult, bool isWin, int opponentShipsDestroyed) {
    stats.totalShots++;
    if (shotResult == 'HIT') {
      stats.hits++;
    } else if (shotResult == 'MISS') {
      stats.misses++;
    }
    stats.shipsDestroyed = opponentShipsDestroyed;
    stats.shipsRemaining = board.shipsRemaining;
    stats.shipsLost = SHIP_SIZES.length - board.shipsRemaining;
  }
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

class StatisticsManager {
  static final StatisticsManager _instance = StatisticsManager._internal();
  factory StatisticsManager() => _instance;
  StatisticsManager._internal();

  Future<void> saveStats(
    GameStats stats1,
    GameStats stats2,
    String winner,
  ) async {
    try {
      // Создаем каталог для статистики
      final statsDir = Directory('game_statistics');
      if (!await statsDir.exists()) {
        await statsDir.create();
      }

      // Создаем файл с текущей датой и временем
      final timestamp = DateTime.now().toString().replaceAll(
        RegExp(r'[:\-\.]'),
        '_',
      );
      final file = File('${statsDir.path}/battle_stats_$timestamp.txt');

      final content =
          '''
МОРСКОЙ БОЙ - СТАТИСТИКА ИГРЫ
Дата: ${DateTime.now()}
Победитель: $winner

${'=' * 50}
СТАТИСТИКА ИГРОКА 1:
${stats1.toString()}

${'=' * 50}
СТАТИСТИКА ИГРОКА 2:
${stats2.toString()}

${'=' * 50}
ОБЩАЯ СТАТИСТИКА:
Всего выстрелов: ${stats1.totalShots + stats2.totalShots}
Всего попаданий: ${stats1.hits + stats2.hits}
Всего промахов: ${stats1.misses + stats2.misses}
Общая точность: ${((stats1.hits + stats2.hits) / (stats1.totalShots + stats2.totalShots) * 100).toStringAsFixed(2)}%
''';

      await file.writeAsString(content);
      print('\nСтатистика сохранена в файл: ${file.path}');
    } catch (e) {
      print('Ошибка при сохранении статистики: $e');
    }
  }

  void displayFinalStats(GameStats stats1, GameStats stats2, String winner) {
    print('\n' + '=' * 60);
    print('ФИНАЛЬНАЯ СТАТИСТИКА ИГРЫ');
    print('ПОБЕДИТЕЛЬ: $winner');
    print('=' * 60);

    print('\n${stats1.playerName}:');
    print('  Уничтожено кораблей противника: ${stats1.shipsDestroyed}');
    print('  Потеряно кораблей: ${stats1.shipsLost}');
    print('  Осталось кораблей: ${stats1.shipsRemaining}/10');
    print('  Попадания/Промахи: ${stats1.hits}/${stats1.misses}');
    print('  Точность: ${stats1.accuracy.toStringAsFixed(2)}%');

    print('\n${stats2.playerName}:');
    print('  Уничтожено кораблей противника: ${stats2.shipsDestroyed}');
    print('  Потеряно кораблей: ${stats2.shipsLost}');
    print('  Осталось кораблей: ${stats2.shipsRemaining}/10');
    print('  Попадания/Промахи: ${stats2.hits}/${stats2.misses}');
    print('  Точность: ${stats2.accuracy.toStringAsFixed(2)}%');

    print('\nОБЩАЯ СТАТИСТИКА:');
    print('  Всего выстрелов: ${stats1.totalShots + stats2.totalShots}');
    print('  Всего попаданий: ${stats1.hits + stats2.hits}');
    print('  Всего промахов: ${stats1.misses + stats2.misses}');
    print(
      '  Длительность игры: ${stats1.gameDuration.inMinutes} мин ${stats1.gameDuration.inSeconds % 60} сек',
    );
  }
}

class Game {
  Player p1, p2;
  int turn = 1;
  List<String> log = [];
  final StatisticsManager statsManager = StatisticsManager();

  Game(this.p1, this.p2);

  void run() {
    // Запускаем отсчет времени для статистики
    p1.stats.startGame();
    p2.stats.startGame();

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

      // Обновляем статистику
      curr.updateStats(res, false, opp.board.shipsSunk);
      opp.stats.shipsRemaining = opp.board.shipsRemaining;
      opp.stats.shipsLost = SHIP_SIZES.length - opp.board.shipsRemaining;

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
        // Завершаем время игры для статистики
        p1.stats.endGame();
        p2.stats.endGame();

        print('${curr.name} победил!');

        // Обновляем финальную статистику
        curr.stats.shipsDestroyed = opp.board.shipsSunk;
        curr.stats.shipsRemaining = curr.board.shipsRemaining;

        // Показываем и сохраняем статистику
        statsManager.displayFinalStats(p1.stats, p2.stats, curr.name);
        statsManager.saveStats(p1.stats, p2.stats, curr.name);

        _end();
        return;
      }
      turn = 3 - turn;
    }
  }

  void _end() {
    print('\nЛог игры: ${log.join('; ')}');
    print('Играть снова? д/н');
    if (stdin.readLineSync()?.toLowerCase() == 'д') {
      p1.board = Board();
      p2.board = Board();
      p1.stats = GameStats(p1.name);
      p2.stats = GameStats(p2.name);
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
