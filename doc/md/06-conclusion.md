[← Chapter 5. A Sample Implementation](05-a-sample-implementation.md) | [↑ Contents](README.md) | [Chapter 7. Bibliography →](07-bibliography.md)

# Chapter 6. Conclusion


## 6.1. Usefulness of Meta-Assemblers

The usefulness of meta-assemblers has been proven by past implementations. Their use has evolved from their macro-based implementations in the 1960s which were used as a forerunner to the high level language, through the 1970s and 1980s when the development of a multitude of microprocessors lead to the need for a tool to develop and implement assemblers quickly and easily, right up to the present day. It is clear that the continuing development of general and special purpose microprocessors will require such a tool for the foreseeable future.

Another area in which the meta-assembler will be used in the future is that of the Universal Compiler. Such a tool can compile a large number of high level languages and produce object code for a large number of computers. The final output stage of this tool is always some form of meta-assembler. The development of universal compilers will continue for the foreseeable future, ensuring the continuing development of faster and more flexible meta- assembler. Such universal compilers have already been implemented, one such being the Amsterdam Compiler Kit which is described in Tanenbaum's 13. 'Structured Computer Organization'

The construction of meta-assemblers will continue to reflect the changes affecting high level language design. As more and more software is being designed using Object Oriented Techniques, so the construction of meta- assemblers will reflect the use of these techniques. The trend so far has been to turn away from table-driven designs in favour of meta-assemblers with a program-based assembler specification. In terms of current programming trends, these will eventually take the form of semi-intelligent, object oriented specifications written in a suitably adapted 5th generation language.

## 6.2. Evaluation of Implementation

### 6.2.1. Overview

The sample implementation takes a data and algorithm-driven approach to the meta-assembler problem. By using the principles of Object Oriented Programming it was possible to re-design a traditional two-pass dedicated assembler into its assembler-dependent and assembler-independent parts. This enabled the implementation of an assembler in Modula-2 which can be re- configured easily to assemble for another processor.

It was decided that the syntax of the assembly language which can be entered into the implementation should conform to the IEEE Assembly Language Standard. In the context of the use of meta-assemblers, this provides a consistent format to which all assembly languages can conform.

### 6.2.2. Speed Of Assembly

The speed of the meta-assembler implementation compares well with other implementations. Running on an IBM XT compatible computer at 10 MHz, assembly speed for various length test programs ranged from 370 lines/minute to 720 lines/minute. In direct comparison with the Generic Meta-Assembler described earlier in section 4.7.7., assembly speed was slightly faster when assembling a 200 line program at 4.77 MHz (3.52 lines/second for the sample implementation compared with 2.74 for the Generative Meta-Assembler).

### 6.2.3. Development Time for a New ADM

Unfortunately, there was not enough time left to implement any other ADM modules (apart from the MC68000 ADM described). A design for a 6502 ADM was developed but not implemented.

The structure of the ADM and its function suggest that development time for processors with orthogonal instruction set should be considerably less than for those whose instruction sets that are not orthogonal. This was certainly true when developing the 6502 ADM as opposed to the MC68000 ADM.

```
                                                      Size of Meta-Assembler
                                                        (Implementation Modules)
                                               TableTrees (3.5%)
                                          TableExt (4.7%)
```

Figure 36 shows how much of the complete program the separate modules of the implementation constitute. It can be seen that the MC68000 ADM constitutes 30% of the complete meta-assembler source program. It is felt, however, that a significant improvement on the length of this file could be made given more time (see section 6.2.4.)

The physical time spent developing the ADM module was again about 30% of the development time of the complete meta-assembler. This translates into approximately 30 man/hours, which compared with other meta-assembler implementations discussed earlier is very reasonable, given the fact that the MC68000 does not have a particularly orthogonal instruction set.

### 6.2.4. Immediate Improvements

This section contains a number of suggestions of what would be done to improve the sample implementation given more time. Each suggestion is followed by either a 'T' or a 'D' which signifies whether the improvement is simply due to a lack of time or whether the improvement constitutes a change in the design of the meta-assembler.

1. The Table module should deallocate memory used (which currently it does not). While this is not a problem for a version implemented on a single- task computer (such as an IBM XT compatible running MS-DOS), this would be a problem on a multi-tasking computer (such as the Commodore Amiga) where memory deallocation is important. (T).

2. A serious flaw in the design of the sample implementation is that the valid addressing modes for any instruction are not included in the table with the opcodes. This leads to a very much larger ADM implementation module. The design should be changed, therefore, so that a set of user defined addressing modes (corresponding to those implemented on the target processor) should be included with the opcodes in the table for every operand used in an instruction. (D).

3. Only one object code format has been implemented. The number should be increased to at least three: * Generic. * Motorola-S format. * Intel format. The selection of the format should be included in an assembler directive so that it can be selected at will by the programmer. (T/D).

4. The design of the ADM for the Motorola MC68000 is not very efficient and could be improved greatly (partly because of point 2 above). (T/D).

5. More ADMs should be written for other processors. (T).

6. No facilities are provided within the Location module to handle page/segment addressed systems. So, for example, a proper Intel 80x86 assembler could not be implemented at present. This problem stems from the lack of information provided in the IEEE standard about how page addressed systems should be handled. A parameter (constant) could be included in the ADM module which would inform the meta-assembler which type of addressing system is to be used (either linear or paged). (D).

7. The speed of implementation could be improved by using an execution profiler to determine where the most time is being spent. Such a profiler is included in the JPI Topspeed Modula-2 package. Very time-critical sections could be re-written using assembly language but this promotes non-portability and should therefore be used as little as possible. (T).

8. The expression evaluator should be improved to allow expressions with more than two operands and priorities provided by parentheses. Such an evaluator would probably be stack-based. The re-implementation of the expression evaluator should not affect the structure of any of the other modules. (D).

### 6.2.5. Future Developments

This section contains suggestions for future developments which would require large alterations to the current implementation.

1. The meta-assembler could be re-designed so that it can produce relocatable code and provide more information to a linker such as external references and symbolic debugging information.

2. A meta-linker would be a useful and viable tool to the meta-assembler. This would produce object code formats based on a specification which is either included within the ADM or separately. If this was included within the ADM then the ADM would specify the complete translation process from an assembly language program to an object code program.

3. The IEEE standard was not necessarily the best standardised processor description method to use. Several methods have been implemented which address some of the problems caused by the IEEE standard. These include the fact that large lexical scanners are needed and that some aspects (such as paged addressing systems) are omitted. The reader is referred to references 27 and 28 for more information.

4. Assembler facilities could be improved to make the meta-assembler more powerful. These would include macro facilities and block structuring of code. This would bring the syntax of the assembly language more in line with those of modern dedicated assemblers.

---

[← Chapter 5. A Sample Implementation](05-a-sample-implementation.md) | [↑ Contents](README.md) | [Chapter 7. Bibliography →](07-bibliography.md)
