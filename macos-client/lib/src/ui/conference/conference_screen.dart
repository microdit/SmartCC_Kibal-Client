import 'package:flutter/material.dart';

class ConferenceView extends StatelessWidget {
  const ConferenceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회의실'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey[200],
        child: Column(
          children: [
            // 내 영상 (고정)
            Container(
              height: 180,
              color: Colors.grey[300],
              child: const Center(child: Text('내 영상 (Local Stream)')),
            ),
            // 참가자 타일 (가상 표시)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 120,
                          color: index % 2 == 0 ? Colors.grey[300] : Colors.grey[400],
                          width: double.infinity,
                          child: const Center(child: Text('원격 영상 ${index + 1}')),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text('참가자 ${index + 1}'),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 60,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.mic,
                    color: Colors.green, size: 24),
                onPressed: () {},
                iconSize: 24,
              ),
              IconButton(
                icon: const Icon(Icons.videocam,
                    color: Colors.green, size: 24),
                onPressed: () {},
                iconSize: 24,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.call_end, color: Colors.white, size: 18),
                label: const Text('종료', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
