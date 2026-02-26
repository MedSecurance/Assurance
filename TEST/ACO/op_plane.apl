
ac_pattern('Op_Plane',
    [],
    goal('G0',
        'The operational plane guarantees the {local policy} is met.',
        [
            context("Case: Op Plane — component architecture"),
            context('The system model describes the plane and its {properties}.')
        ],
        [
            goal('G1',
                'Compositional behaviour of separate components ensures the local policy is met.',
                [],
                [
                    goal('M1',
                        'Behaviour of the {component} meets its local policy.',
                        [],
                        []
                    )
                ]
            ),
            goal('G2',
                'Compositional behaviour of compositions ensures the local policy is met.',
                [],
                [
                    goal('M2',
                        'Behaviour of the {composition} meets the local policy.',
                        [],
                        []
                    )
                ]
            ),
            goal('M0',
                'Interaction between components and compositions is as defined by the security architecture interface.',
                [],
                []
            )
        ]
    )
).
