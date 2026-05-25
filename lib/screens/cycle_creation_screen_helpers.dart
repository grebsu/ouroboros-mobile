  Widget _buildCurrentStepContent(BuildContext context, AllSubjectsProvider allSubjectsProvider) {
    switch (_currentStep) {
      case 0:
        return _buildSubjectSelection(allSubjectsProvider);
      // Add other cases here for steps 1-6
      default:
        return const Center(child: Text("Em desenvolvimento"));
    }
  }

  Widget _buildSubjectSelection(AllSubjectsProvider allSubjectsProvider) {
    final filteredSubjects = allSubjectsProvider.uniqueSubjectsByName
        .where((s) => s.subject.toLowerCase().contains(_subjectSearchQuery.toLowerCase()))
        .toList();
    
    return Column(
      children: [
        TextField(
          controller: _subjectSearchController,
          decoration: const InputDecoration(labelText: 'Buscar matéria', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredSubjects.length,
            itemBuilder: (context, index) {
              final subject = filteredSubjects[index];
              final isSelected = _selectedSubjects.contains(subject.id);
              final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
              
              return InkWell(
                onTap: () => setState(() => isSelected ? _selectedSubjects.remove(subject.id) : _selectedSubjects.add(subject.id)),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: isSelected ? 2 : 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    subject.subject,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
