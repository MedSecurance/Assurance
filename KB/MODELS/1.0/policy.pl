policy(main,
       [subject('S1',
                [port(p, [], [])],
                [],
                [processor(x, [family(cpu), frequency('2GHz'), schedule(70)]),
                 memory(z, [family(ram), size(1)])]),
        subject(s2,
                [port(p, [], [])],
                [],
                [processor(x, [family(cpu), frequency('2GHz'), schedule(80)]),
                 memory(z, [family(ram), size(5)])])],
       [object(o1,
               [],
               [memory(u, [family(ram), size(3)])]),
        object(o2,
               [],
               [memory(u, [family(ram), size(6)])])],
       
       [ss_flow(s1s2, ['S1', p], [s2, p], [], [])],
       
       [so_flow(s1o1, 'S1', o1, [], []),
        so_flow(s2o2, s2, o2, [], [])],
       
       [milsfilename('x.mils')],
       
       [deployment(not_same(['S1', s2]))
       ]).

