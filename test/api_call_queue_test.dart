import 'package:eval/src/services/service.dart';
import 'package:test/test.dart';

enum TestServiceType { serviceA, serviceB }

void main() {
  group('APICallQueue', () {
    late APICallQueue queue;

    setUp(() {
      queue = APICallQueue();
    });

    group('registerCallQueue', () {
      test('should register a new queue for a service type', () async {
        await queue.registerCallQueue<TestServiceType>();

        expect(queue.queues.containsKey('TestServiceType'), isTrue);
        expect(queue.queues['TestServiceType'], isA<Future>());
      });

      test('should not overwrite existing queue', () async {
        await queue.registerCallQueue<TestServiceType>();
        final firstQueue = queue.queues['TestServiceType'];

        await queue.registerCallQueue<TestServiceType>();
        final secondQueue = queue.queues['TestServiceType'];

        expect(identical(firstQueue, secondQueue), isTrue);
      });

      test(
        'should register different queues for different service types',
        () async {
          await queue.registerCallQueue<TestServiceType>();
          await queue.registerCallQueue<String>();

          expect(queue.queues.containsKey('TestServiceType'), isTrue);
          expect(queue.queues.containsKey('String'), isTrue);
          expect(
            identical(queue.queues['TestServiceType'], queue.queues['String']),
            isFalse,
          );
        },
      );
    });

    group('addCallByType', () {
      test('should throw exception when queue is not registered', () async {
        callback() async => 'test result';

        expect(
          () => queue.addCallByType<TestServiceType>(
            callback,
            Duration(milliseconds: 100),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'No call queue was registered for service TestServiceType',
              ),
            ),
          ),
        );
      });

      test(
        'should execute callback after delay when queue is registered',
        () async {
          await queue.registerCallQueue<TestServiceType>();

          final startTime = DateTime.now();
          callback() async => 'test result';
          const delay = Duration(milliseconds: 200);

          final result = await queue.addCallByType<TestServiceType>(
            callback,
            delay,
          );
          final endTime = DateTime.now();
          final actualDelay = endTime.difference(startTime);

          expect(result, equals('test result'));
          expect(
            actualDelay.inMilliseconds,
            greaterThanOrEqualTo(delay.inMilliseconds - 50),
          );
        },
      );

      test(
        'should execute callbacks sequentially for same service type',
        () async {
          await queue.registerCallQueue<TestServiceType>();

          final executionOrder = <int>[];
          callback1() async {
            executionOrder.add(1);
            return 'result1';
          }

          callback2() async {
            executionOrder.add(2);
            return 'result2';
          }

          callback3() async {
            executionOrder.add(3);
            return 'result3';
          }

          const delay = Duration(milliseconds: 50);

          final future1 = queue.addCallByType<TestServiceType>(
            callback1,
            delay,
          );
          final future2 = queue.addCallByType<TestServiceType>(
            callback2,
            delay,
          );
          final future3 = queue.addCallByType<TestServiceType>(
            callback3,
            delay,
          );

          final results = await Future.wait([future1, future2, future3]);

          expect(results, equals(['result1', 'result2', 'result3']));
          expect(executionOrder, equals([1, 2, 3]));
        },
      );

      test(
        'should allow parallel execution for different service types',
        () async {
          await queue.registerCallQueue<TestServiceType>();
          await queue.registerCallQueue<String>();

          final executionOrder = <String>[];
          final startTime = DateTime.now();

          callbackA() async {
            executionOrder.add('A');
            return 'resultA';
          }

          callbackB() async {
            executionOrder.add('B');
            return 'resultB';
          }

          const delay = Duration(milliseconds: 100);

          final futureA = queue.addCallByType<TestServiceType>(
            callbackA,
            delay,
          );
          final futureB = queue.addCallByType<String>(callbackB, delay);

          final results = await Future.wait([futureA, futureB]);
          final endTime = DateTime.now();
          final totalTime = endTime.difference(startTime);

          expect(results, equals(['resultA', 'resultB']));
          expect(executionOrder.length, equals(2));
          expect(executionOrder, containsAll(['A', 'B']));
          expect(totalTime.inMilliseconds, lessThan(200));
        },
      );

      test('should handle callback exceptions properly', () async {
        await queue.registerCallQueue<TestServiceType>();

        callback() async {
          throw Exception('Test exception');
        }

        expect(
          () => queue.addCallByType<TestServiceType>(
            callback,
            Duration(milliseconds: 50),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Test exception'),
            ),
          ),
        );
      });

      test('should respect timing between sequential calls', () async {
        await queue.registerCallQueue<TestServiceType>();

        final timestamps = <DateTime>[];
        callback1() async {
          timestamps.add(DateTime.now());
          return 'result1';
        }

        callback2() async {
          timestamps.add(DateTime.now());
          return 'result2';
        }

        const delay = Duration(milliseconds: 100);

        final future1 = queue.addCallByType<TestServiceType>(callback1, delay);
        final future2 = queue.addCallByType<TestServiceType>(callback2, delay);

        await Future.wait([future1, future2]);

        expect(timestamps.length, equals(2));
        final timeDifference = timestamps[1].difference(timestamps[0]);
        expect(
          timeDifference.inMilliseconds,
          greaterThanOrEqualTo(delay.inMilliseconds - 50),
        );
      });

      test('should handle zero delay', () async {
        await queue.registerCallQueue<TestServiceType>();

        callback() async => 'immediate result';

        final startTime = DateTime.now();
        final result = await queue.addCallByType<TestServiceType>(
          callback,
          Duration.zero,
        );
        final endTime = DateTime.now();
        final actualDelay = endTime.difference(startTime);

        expect(result, equals('immediate result'));
        expect(actualDelay.inMilliseconds, lessThan(50));
      });
    });

    group('integration tests', () {
      test(
        'should handle multiple service types with different delays',
        () async {
          await queue.registerCallQueue<TestServiceType>();
          await queue.registerCallQueue<String>();
          await queue.registerCallQueue<int>();

          final results = <String>[];
          final timestamps = <DateTime>[];

          callback1() async {
            timestamps.add(DateTime.now());
            results.add('service1');
            return 'result1';
          }

          callback2() async {
            timestamps.add(DateTime.now());
            results.add('string1');
            return 'result2';
          }

          callback3() async {
            timestamps.add(DateTime.now());
            results.add('int1');
            return 'result3';
          }

          final futures = [
            queue.addCallByType<TestServiceType>(
              callback1,
              Duration(milliseconds: 100),
            ),
            queue.addCallByType<String>(callback2, Duration(milliseconds: 150)),
            queue.addCallByType<int>(callback3, Duration(milliseconds: 50)),
          ];

          await Future.wait(futures);

          expect(results.length, equals(3));
          expect(results, containsAll(['service1', 'string1', 'int1']));
          expect(timestamps.length, equals(3));
        },
      );

      test(
        'should handle rapid sequential calls for same service type',
        () async {
          await queue.registerCallQueue<TestServiceType>();

          final results = <String>[];
          final callbacks = List.generate(
            5,
            (index) => () async {
              results.add('result$index');
              return 'result$index';
            },
          );

          final futures = callbacks
              .map(
                (callback) => queue.addCallByType<TestServiceType>(
                  callback,
                  Duration(milliseconds: 20),
                ),
              )
              .toList();

          await Future.wait(futures);

          expect(
            results,
            equals(['result0', 'result1', 'result2', 'result3', 'result4']),
          );
        },
      );
    });
  });
}
