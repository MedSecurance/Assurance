
ac_pattern('Op_Plane',
    [],
    goal('G1.',
        'The operational plane guarantees the {local policy} is met.',
        [
            context("Case: Op Plane — component architecture"),
            context('The system model describes the plane and its {properties}.')
        ],
        [
            goal('G1.2',
                'Compositional behaviour of separate components ensures the local policy is met.',
                [],
                [
                    goal('M1.2.1',
                        'Behaviour of the {component} meets its local policy.',
                        [],
                        []
                    )
                ]
            ),
            goal('G1.3',
                'Compositional behaviour of compositions ensures the local policy is met.',
                [],
                [
                    goal('M1.3.1',
                        'Behaviour of the {composition} meets the local policy.',
                        [],
                        []
                    )
                ]
            ),
            goal('M1.4',
                'Interaction between components and compositions is as defined by the security architecture interface.',
                [],
                []
            )
        ]
    )
).
