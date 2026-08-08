INSERT INTO level_info (
    id, campaign_id, level_name, world_map_x, world_map_y,
    started_at, ended_at, starting_money, num_starting_lives, num_waves,
    playable_rect_x, playable_rect_y, playable_rect_width, playable_rect_height,
    map_image_name, map_image_width, map_image_height
) VALUES (
    '33d900c6-c6ff-409a-973b-f09ddc8a6f6a',
    'f589a28f-54d8-4791-851c-a307f252151a',
    'Kettle Creek',
    1400.0,
    1330.0,
    julianday('1779-02-14T10:00:00-05:00'),
    julianday('1779-02-14T13:00:00-05:00'),
    430,
    20,
    15,
    960.0, 540.0, 3840.0, 2160.0,
    'level_012_kettle_creek', 5760.0, 3240.0
);

INSERT INTO tower_slot (
    id, level_info_id, map_position_x, map_position_y
) VALUES
('ba54fc73-56c2-5efc-9e37-20b0f7c7b667', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1843.0, 1546.0),
('27545c27-92d8-5517-ae16-37875e2d7679', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 2098.0, 1584.0),
('26aea483-ee72-5add-bfa6-32152b3d9e5a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 2828.0, 1642.0),
('f9e5c21f-9eb0-5470-9a94-7c79d91a8b44', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 3128.0, 1560.0),
('35d7f753-549e-545e-8f5a-6918289b512a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 4031.0, 1147.0),
('47ef7a71-cbaf-5460-89e9-eb5fd0393a56', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 4100.0, 1363.0),
('a35fe12a-e828-5699-ae70-8cf4d13f884b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 4065.0, 1594.0),
('ba8fa728-4ba7-5335-8edf-6b5f01092d54', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 3521.0, 1945.0),
('6fea0476-cefc-5104-994c-7d4a2f6151e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 3865.0, 2128.0),
('b3a06ab5-4f0e-5e8d-9262-68f372917b12', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 4416.0, 2159.0);

INSERT INTO level_path_point (
    id, level_info_id, path_index, point_index,
    map_position_x, map_position_y
) VALUES
('84ad634b-aaee-5b22-bccd-92d3948d4a53', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 0, 1574.0, 1997.0),
('2720313e-ca68-5d36-8235-631605ef032d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1, 1575.9, 1994.7),
('1a2d2ad5-5c86-5ef5-aef7-67777970e723', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 2, 1577.7, 1992.3),
('83183a1c-d57f-55be-beef-ed4b4e657d8b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 3, 1579.6, 1990.0),
('9ebfeaf2-7f1e-58b1-9eaf-45d6222d34d3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 4, 1581.5, 1987.7),
('6ca8ddd2-991d-55d1-bbd7-4556015e5e94', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 5, 1583.4, 1985.3),
('bc398fc6-81ac-53f9-99e1-5bc3c58e771a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 6, 1585.3, 1983.0),
('cf918cae-f477-5746-bf02-ae6c67baf6f9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 7, 1587.2, 1980.7),
('090cf1e6-9e7e-57a3-ab33-00d01ade4619', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 8, 1589.1, 1978.4),
('a0c24599-bf3f-5227-aff4-bc4c368982a3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 9, 1591.0, 1976.1),
('6b198ade-0b37-5fb4-940e-9ecfec697db4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 10, 1592.9, 1973.7),
('491a9409-c74d-5322-ba3e-4b942f64e0c5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 11, 1594.8, 1971.4),
('70178647-6e02-5e57-8313-82837a54fd2d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 12, 1596.7, 1969.1),
('e36cf02c-6381-5b8e-8e3d-e2d3635b1433', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 13, 1598.6, 1966.7),
('d95f45e3-69c0-5a70-bb97-3fa3bfddad34', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 14, 1600.5, 1964.4),
('a1fd7134-e38f-5bb0-a7cd-596d473d7d6b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 15, 1602.4, 1962.1),
('67ee45ed-1573-5493-9924-54f2f44c2709', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 16, 1604.3, 1959.7),
('b26fbdfd-cabb-51f0-b59c-d4036d679e7b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 17, 1606.1, 1957.4),
('443c9723-4631-5f1c-ba81-e8afd3b10de4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 18, 1608.0, 1955.0),
('12b273fd-f136-57d2-b14e-fe12ef9841a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 19, 1609.8, 1952.7),
('baa7f3ed-ff20-5ac9-a7d4-be1defe3d5dc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 20, 1611.7, 1950.3),
('336d21b9-8451-564b-8f1b-035ee974b411', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 21, 1613.5, 1948.0),
('b0acb898-8b8b-599f-a9b4-7b0cb7eaafe7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 22, 1615.4, 1945.6),
('8c0c9c96-6b8e-51c0-9572-ca07ed7e9a11', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 23, 1617.2, 1943.2),
('a663a818-03e7-5c08-a28e-76ad6849bd76', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 24, 1619.1, 1940.8),
('83314522-10dd-5e02-b20b-f96629661127', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 25, 1620.9, 1938.5),
('f4f733d0-eae0-56cb-8718-1f599dbb0bf1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 26, 1622.7, 1936.1),
('e28dacb1-3b76-5da7-b861-f0eb542e0e1f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 27, 1624.5, 1933.7),
('eb0a186f-6659-5bd4-b3b4-e806dc9d9ca4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 28, 1626.3, 1931.3),
('eb6b8648-17cb-54dc-8a7f-b3cb28b59104', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 29, 1628.1, 1928.9),
('f7ef304f-d2fb-57f3-8f62-3a4b20a63866', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 30, 1629.9, 1926.5),
('50175196-599c-544d-9731-1272077a7ef7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 31, 1631.6, 1924.0),
('c66e86ca-28f3-5cf6-ab7e-d21c592db2a0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 32, 1633.4, 1921.6),
('52c959df-d1f0-5bb0-9705-2f1edaa84c87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 33, 1635.2, 1919.2),
('279918fb-8d7b-5234-8160-9e272d92a8a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 34, 1636.9, 1916.7),
('cb08fcdb-3be0-5f50-abb0-16b36d2d076e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 35, 1638.6, 1914.3),
('0f05167d-cd0e-5edb-9199-6b7ef4465c5e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 36, 1640.2, 1911.7),
('a7f89a4f-378c-50f8-b0f7-6303d92943e6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 37, 1641.9, 1909.2),
('2711fd2b-1360-587e-93db-7baf0a02bd2a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 38, 1643.5, 1906.7),
('87fdb26e-3b89-5ea8-b631-4873cf9d5e5f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 39, 1645.0, 1904.1),
('8033de29-ef7b-567b-8cab-37f18b6aac33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 40, 1646.6, 1901.5),
('b32d5604-a07c-5631-9ea8-d2b7c122d7d6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 41, 1648.1, 1899.0),
('ec62d30f-9586-526a-8ad8-a896c4578589', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 42, 1649.6, 1896.4),
('e7cdee0b-1fd2-5ca9-9cf7-6ad71952d9d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 43, 1651.1, 1893.7),
('e162f3b2-d347-5673-b78a-290f039ccdcc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 44, 1652.5, 1891.1),
('0607d7bc-7a7f-597e-9c63-07912ae57d0f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 45, 1654.0, 1888.5),
('69fdb00e-7fc8-5f84-b914-c527a3381ce1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 46, 1655.4, 1885.9),
('b0316bd6-942a-5cc1-a462-d3d62f3e872b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 47, 1656.8, 1883.2),
('5e820b80-e23d-5463-8269-25ca1b06ec71', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 48, 1658.3, 1880.6),
('1c74dad5-c699-5246-9c6b-4828bcfdaeeb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 49, 1659.7, 1878.0),
('6c3ed31d-77a4-529d-9621-6b71a34c5995', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 50, 1661.1, 1875.3),
('22d7d23c-4532-5f9c-8ece-50d18c1c9bb9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 51, 1662.6, 1872.7),
('8a95abe1-7bda-578b-a7bf-6b59ca9bd472', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 52, 1664.0, 1870.1),
('8a30fa69-1450-5a3c-89ac-36a745619f96', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 53, 1665.4, 1867.4),
('02669e91-6b80-5d04-8e73-e5b0ed0a2cd1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 54, 1666.9, 1864.8),
('159731e8-2a8d-5f9a-8f55-2270919dd918', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 55, 1668.3, 1862.2),
('243ac584-95cd-55d9-951e-11dfddcaeb0d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 56, 1669.8, 1859.5),
('636c1c3b-6469-5f34-81f1-9b3ec2c6354e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 57, 1671.3, 1856.9),
('c81c93f8-838c-5401-924d-c9486a42e437', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 58, 1672.7, 1854.3),
('43d17cce-1d37-560c-b899-ec4d270c36d3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 59, 1674.2, 1851.7),
('bffe3111-02f5-5e7a-b37a-224c8ed7a16a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 60, 1675.8, 1849.1),
('a736ff94-fd3a-5786-8338-bb0034a39f38', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 61, 1677.3, 1846.6),
('0f09a9cb-b52a-5a7f-bb0e-a5d740036f42', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 62, 1678.8, 1844.0),
('e6c123cc-4df2-5abd-b19a-979ef2c0d0e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 63, 1680.4, 1841.4),
('c750ce05-6883-5e43-95ea-5ed8ebda6df3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 64, 1682.0, 1838.9),
('be8b8638-074a-5fe7-a6d4-ef8ecdcfac15', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 65, 1683.6, 1836.3),
('28f86213-6778-5a57-ab8c-5637c8f5cea8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 66, 1685.2, 1833.8),
('63f2b54b-2d35-5de3-9bf3-580e3f41ae2a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 67, 1686.9, 1831.3),
('0136c1c4-99f3-5310-8f5d-bc34233cc256', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 68, 1688.6, 1828.8),
('297ba3da-576b-5e28-97d0-a0010260e922', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 69, 1690.3, 1826.4),
('a61d2f9f-4425-5e6b-8fc6-2446395dfeff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 70, 1692.0, 1823.9),
('e2f6e1d6-9da8-5220-a44f-fded6e6d61d8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 71, 1693.8, 1821.5),
('2930fc2b-d435-53f2-a1d4-0b7248a517a2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 72, 1695.6, 1819.1),
('ca16dc37-2c7f-56f0-abf5-327688039497', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 73, 1697.4, 1816.7),
('2ba139f3-5296-5f6a-9e90-d55f82503694', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 74, 1699.2, 1814.3),
('31fb1c15-fcd0-59f2-9205-955db9ff968b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 75, 1701.1, 1812.0),
('83e09e64-e237-55c1-9cd5-f2054b068803', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 76, 1703.0, 1809.7),
('a8205cf8-04ed-5a94-9d28-394152788b87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 77, 1705.0, 1807.4),
('5b7818b5-ff07-5b28-bcea-6f4e14af31a7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 78, 1706.9, 1805.1),
('c5d2da1b-0cb5-5033-9f60-79551c5d024d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 79, 1709.0, 1802.9),
('5cf0984b-b38f-5aa4-9ca4-a6722b655405', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 80, 1711.0, 1800.7),
('b853b1e8-412b-502b-8de1-e0dde679f6d0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 81, 1713.1, 1798.6),
('e7a022f8-4b1e-51e8-b1b0-df451c8a93fd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 82, 1715.2, 1796.4),
('eda88a1f-f9fa-5a8f-8a2c-e49053080865', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 83, 1717.3, 1794.3),
('70880ce8-53db-54d5-914b-05c5d23c8991', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 84, 1719.5, 1792.3),
('acd76e45-0712-5339-b2dd-dab1fe255a10', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 85, 1721.7, 1790.3),
('e7756fc0-1c12-5c39-b71f-2eebc76d93e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 86, 1724.0, 1788.3),
('7bf420f1-15fe-5df0-a60f-5a9c5e2e9631', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 87, 1726.2, 1786.3),
('fbd10a66-9630-5e66-9079-752739bcc869', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 88, 1728.5, 1784.3),
('085e00b7-66f6-549b-b5ee-d088db95a353', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 89, 1730.8, 1782.4),
('3ef621b2-85a3-5ada-b256-12e2c0c37c79', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 90, 1733.1, 1780.5),
('bd082dbe-6e61-57be-a39e-8335a63d58ba', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 91, 1735.4, 1778.6),
('68de35d1-2951-502b-ad6c-edcb6032d089', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 92, 1737.8, 1776.7),
('c50368c3-74fa-5bfa-a325-149865fe0b39', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 93, 1740.1, 1774.8),
('e9af52c0-5fbe-5be0-95ed-b18cd5e5cb56', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 94, 1742.5, 1773.0),
('a38d03ee-2f70-54c1-b4ff-403a4aaa55dd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 95, 1744.8, 1771.1),
('097af615-e85d-582f-ae8b-d34821c58b61', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 96, 1747.2, 1769.3),
('a6ba8673-9c49-5f2e-a270-a997a622f579', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 97, 1749.6, 1767.5),
('3cf46d2f-b89d-581f-9902-6bcc11d91a9c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 98, 1752.0, 1765.7),
('9d9926d4-e181-5df2-a50f-a23e616a1215', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 99, 1754.4, 1763.9),
('3bd39422-abd7-5749-ae5a-d3d5ef7e6d32', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 100, 1756.8, 1762.2),
('28875ef4-59ec-54d7-b329-5a9e077a28bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 101, 1759.3, 1760.4),
('f724ba25-f206-55c6-9e7a-44e81e50e0c4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 102, 1761.7, 1758.7),
('e9600f9c-85bf-5476-9fa3-5a46b583d352', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 103, 1764.2, 1756.9),
('304603de-44a2-58ef-867c-07da2df7c5c3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 104, 1766.6, 1755.2),
('a1985306-9be9-5acd-8d5a-1699d3316dd4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 105, 1769.1, 1753.5),
('9f2fc01c-ea33-5d0a-a7cc-094798cda2dc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 106, 1771.6, 1751.8),
('a620b139-1ffd-5212-ac89-df0c0b0f8985', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 107, 1774.1, 1750.1),
('98eb447a-7fae-5e4a-9e60-017ccdbb857c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 108, 1776.6, 1748.5),
('deaf86df-4642-58ef-b02a-fb684f72b5d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 109, 1779.1, 1746.8),
('08ad647e-9d84-5b60-b452-4980e6a1c9b5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 110, 1781.6, 1745.2),
('8fb8d4b6-88c7-5fd3-83a5-d73fb5fc5490', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 111, 1784.1, 1743.6),
('f5e695aa-e8ad-56ca-9729-5e9177e2c296', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 112, 1786.6, 1741.9),
('0b6824ec-0457-5309-b9c3-eed7098d6c71', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 113, 1789.2, 1740.3),
('9c858274-8d76-52f5-a737-b91760b7bf2c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 114, 1791.7, 1738.7),
('f26e4c01-ec1e-542f-a868-95d7de4569d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 115, 1794.3, 1737.2),
('4492207f-b2ab-503b-972a-1a7731c9b7b5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 116, 1796.8, 1735.6),
('3a2171c3-1202-5d77-9272-5bcc739fad34', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 117, 1799.4, 1734.0),
('4c3d11f8-3319-5c70-8c90-2b6d8e43ab5f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 118, 1802.0, 1732.5),
('9070cd66-a8e5-5d3b-b80d-b125caa24b6e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 119, 1804.5, 1731.0),
('41f3a795-4d92-5459-af34-7516fd4f5269', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 120, 1807.1, 1729.5),
('d8eb7312-8725-5943-a06e-1962ec6ef67c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 121, 1809.7, 1727.9),
('0b92d613-40fb-5725-a7cf-965a4190fb91', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 122, 1812.3, 1726.5),
('46428170-2c99-5074-8f9f-4aef84074871', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 123, 1814.9, 1725.0),
('58fd2ca3-b77b-5546-b581-29e53982331e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 124, 1817.5, 1723.5),
('4ca30d50-d638-5acf-93bd-063a2387f15f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 125, 1820.2, 1722.0),
('5e90c0fe-9116-575f-8b83-39dc4f2d9abd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 126, 1822.8, 1720.6),
('1616afd9-ac25-58ba-a644-1bf7c292c8fc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 127, 1825.4, 1719.2),
('b2aa4f62-b23c-5abd-9aef-057cee72fa88', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 128, 1828.1, 1717.7),
('0da37226-1768-546e-bec7-f1e8ff8c43f2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 129, 1830.7, 1716.3),
('c4f1852c-e1d7-56b8-99b9-764cfe12eca6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 130, 1833.4, 1714.9),
('04faf435-f614-53da-9a0e-4ae2c1286dd3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 131, 1836.0, 1713.6),
('e95fd962-fd2a-572d-9832-b6b0f10f947f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 132, 1838.7, 1712.2),
('2cccf1e4-aaee-5ca9-a8e3-223e0285dec3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 133, 1841.4, 1710.8),
('012b8d02-bede-51cb-972c-a3ee4d0d5310', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 134, 1844.1, 1709.5),
('4cd81508-ee3d-57dd-b44b-639ad18b2cac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 135, 1846.7, 1708.1),
('405c7788-e348-5bea-bab6-2edf857df09d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 136, 1849.4, 1706.8),
('eb7048c6-baad-5867-b7c5-7fee33efa2bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 137, 1852.1, 1705.5),
('3fedf45e-f423-538b-a236-bd9051896a54', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 138, 1854.8, 1704.2),
('4e2db04c-7a0d-5763-acad-09d43f51b9c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 139, 1857.6, 1702.9),
('45564240-3182-5b5e-b1d8-4e2c91aa0e49', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 140, 1860.3, 1701.7),
('c2743343-7a42-5caf-b1a6-33c7f3a5dd6e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 141, 1863.0, 1700.4),
('b4bedd54-63bd-5451-98a0-39b1484a4dc1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 142, 1865.7, 1699.2),
('87bd9177-9482-5ec9-b222-18ae77cc6662', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 143, 1868.5, 1698.0),
('5ea0e2b9-1a6e-5639-bb7e-c467ac12e2e3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 144, 1871.2, 1696.7),
('0be17c84-f4b7-591f-9a2e-90d0e66d6514', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 145, 1874.0, 1695.6),
('84d4fc76-3ce7-5190-a25f-3feed5bb103f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 146, 1876.7, 1694.4),
('0453e5c8-a3ab-5040-b694-57dd76fc86ce', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 147, 1879.5, 1693.2),
('61dcda15-1a57-5249-b4c0-5bf862416136', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 148, 1882.3, 1692.1),
('a381ae5c-b739-5e9c-8958-4218022fd7c5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 149, 1885.0, 1690.9),
('4b7b8885-a7eb-57df-bc15-dbef228f5ef8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 150, 1887.8, 1689.8),
('97eda045-9b3e-5dda-9442-df1ae03d6328', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 151, 1890.6, 1688.7),
('ae415089-7d6a-5e1c-89b9-f99443936d41', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 152, 1893.4, 1687.6),
('ae480027-8f4b-5e3f-93fb-9aad0d24871a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 153, 1896.2, 1686.6),
('c88ee776-7ae8-5bb1-ae58-0af948bb4939', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 154, 1899.0, 1685.5),
('40352490-8911-5a70-b0bd-868206577530', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 155, 1901.9, 1684.5),
('ead1830b-dcfe-5468-bca4-a351f0321769', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 156, 1904.7, 1683.6),
('ff9f705e-b30a-5b9e-8580-6d2befad41b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 157, 1907.6, 1682.6),
('0c5d0573-652b-5883-a37c-8c3a70ab2dee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 158, 1910.4, 1681.7),
('eecbb286-e0d5-5834-a4ba-7e41b68f4f3e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 159, 1913.3, 1680.8),
('5e6290e9-25f9-5c6e-99db-30ba4871c1a3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 160, 1916.2, 1680.0),
('3bca18f5-c1e2-5d33-8350-8d880010de2a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 161, 1919.0, 1679.1),
('d64e7c6d-74bd-5620-ac91-746b8a15ed70', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 162, 1921.9, 1678.4),
('f2b13d54-75aa-520a-8f19-439a7747aae3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 163, 1924.8, 1677.6),
('7dcbf672-6c09-5a1e-8c1c-9042fa98fa51', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 164, 1927.7, 1676.8),
('28e6ba68-9c5e-5a2e-8ed0-0f3c4117f2b0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 165, 1930.6, 1676.1),
('8b39670b-e8ff-58d5-b7dc-3188b8775f49', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 166, 1933.6, 1675.4),
('c5502684-59b4-500c-87c3-18a86f8ba3aa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 167, 1936.5, 1674.7),
('012d36c5-efed-545a-b3df-710d2b9afde8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 168, 1939.4, 1674.1),
('44e8f4a9-50c2-5483-b832-7dfa3cbb4a1f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 169, 1942.3, 1673.4),
('340f1d96-923f-5d56-aa45-0909e1a38cca', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 170, 1945.3, 1672.8),
('50ed7749-2dca-5f8d-b46e-3eede56b8d8a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 171, 1948.2, 1672.2),
('03d03ebe-02fa-5639-ad57-ed66361e114c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 172, 1951.2, 1671.6),
('3c69ff5a-09a7-5c50-b73e-0ae7f5c40389', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 173, 1954.1, 1671.1),
('342b3e85-d11d-5728-a4e4-1bcef1029539', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 174, 1957.1, 1670.5),
('a8b2d04a-95a6-5af3-9cc0-46ab589298b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 175, 1960.0, 1670.0),
('32d92dc8-3fe4-5699-9dfb-a0dea81c8c2d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 176, 1963.0, 1669.5),
('023af66e-c5bb-50d2-a7c9-c0b2ec3b2036', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 177, 1965.9, 1669.0),
('b211b83b-2a64-58c7-89cb-3bf7472c8711', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 178, 1968.9, 1668.5),
('a0ceb756-e1fa-5d05-adaa-a2557b01323a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 179, 1971.8, 1668.0),
('4b7144ca-503e-515b-ae2d-44b25aba7dc2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 180, 1974.8, 1667.5),
('4d14e438-445e-5eb8-8fd3-20ef1d129d65', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 181, 1977.8, 1667.0),
('e39d9790-b0f5-5f3e-bd20-bb6a2181e801', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 182, 1980.7, 1666.6),
('50ba4478-6bff-5b4f-9db1-d3440026060c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 183, 1983.7, 1666.1),
('73db915a-e0c1-5c59-9170-1f2028772516', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 184, 1986.7, 1665.7),
('010d93e0-3a1b-5e6f-92f5-1b0225ca5cb1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 185, 1989.6, 1665.3),
('eb05112f-7bef-533d-9abc-621c1b1c4aa9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 186, 1992.6, 1664.8),
('63b0f27f-1c2b-5314-9392-7a9416b8f475', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 187, 1995.6, 1664.4),
('afa411bd-c1f5-5db8-bb8f-9cb41d2ebac4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 188, 1998.5, 1664.0),
('eae792de-b7a2-50bc-97d7-ead466beff87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 189, 2001.5, 1663.6),
('1c2a7454-bd77-5d33-89ac-dc8eacc3b90f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 190, 2004.5, 1663.2),
('3683afcf-2dd0-51cf-8206-8a9269274aae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 191, 2007.5, 1662.8),
('056fabd3-ff8d-5438-83c0-8c5c8db2b7df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 192, 2010.4, 1662.3),
('ba56b08e-34d4-5ae5-8c77-94a19608c628', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 193, 2013.4, 1661.9),
('6def3ecb-61c8-543c-8c39-67454d9d0730', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 194, 2016.4, 1661.5),
('4951dcac-5d73-5870-a978-b668debfbc61', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 195, 2019.3, 1661.1),
('ee9bdfa5-3881-5536-acd0-813fc4629194', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 196, 2022.3, 1660.7),
('5aab144e-2f70-5792-b481-66c8ff6e8ce7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 197, 2025.3, 1660.3),
('2c497c84-a3d1-59a6-a272-525abb541f36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 198, 2028.3, 1659.8),
('e2c7dc8d-b373-56ee-a42d-ff6701f37b82', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 199, 2031.2, 1659.4),
('b85705aa-cd13-52dd-8c7d-e2b1382c2958', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 200, 2034.2, 1659.0),
('51d547a6-2b47-5e10-adef-92c32e867f0f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 201, 2037.2, 1658.5),
('c5c9d01a-3827-5024-83f4-c68aa569a624', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 202, 2040.1, 1658.1),
('f1fedcfb-21a0-579f-a106-2a3c15cf4acc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 203, 2043.1, 1657.6),
('911ea77d-8ed5-5235-b694-29edcff392ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 204, 2046.1, 1657.2),
('d44b4f52-0232-5549-bf7d-0b62c93a59f1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 205, 2049.0, 1656.7),
('aa8400d3-b6d0-5209-8414-2ffe21f96656', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 206, 2052.0, 1656.2),
('7287f760-e7d5-597c-a197-a24c4dfb516e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 207, 2054.9, 1655.7),
('b4c19376-eaa1-5318-96ce-124d72194d39', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 208, 2057.9, 1655.2),
('119121fb-0409-5344-979e-8a1ed7593212', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 209, 2060.8, 1654.7),
('ca327d43-3456-5a32-bcf0-15303d5795d3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 210, 2063.8, 1654.2),
('4048aa0e-7a6a-54dd-b5c2-9e03295b5050', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 211, 2066.8, 1653.6),
('8714c166-9321-56c0-8dc9-10323fc4d87a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 212, 2069.7, 1653.1),
('f94b8afd-8f51-5d51-b2de-4f76a3ffb942', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 213, 2072.6, 1652.5),
('4c14dda3-baa0-585d-8d0f-0205052c5eff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 214, 2075.6, 1651.9),
('2f69e0ee-37a2-5197-88c2-179c30fdea55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 215, 2078.5, 1651.3),
('324364f8-42ce-5d5e-98cc-813ef92a8105', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 216, 2081.5, 1650.7),
('3f6507af-83c7-5834-9510-90e2e3615e5e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 217, 2084.4, 1650.0),
('62dbcddd-8f62-5eb9-9735-a21f86db3900', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 218, 2087.3, 1649.4),
('3451a460-72b1-5c31-a27c-c70542c53d08', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 219, 2090.2, 1648.7),
('0b49eb8d-1368-5102-920b-788e58a54411', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 220, 2093.2, 1648.0),
('786d4559-4ea5-5e89-b572-b6f21fe28537', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 221, 2096.1, 1647.3),
('898966af-3339-547c-a708-a661648a8c0c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 222, 2099.0, 1646.5),
('97c67d23-c1d8-5ac6-be42-a8f386a69e9b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 223, 2101.9, 1645.8),
('2f632c77-dd8a-5ffb-a98c-aad1e36adf61', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 224, 2104.8, 1645.0),
('eb76441d-d5ab-547f-8ad1-91948e9fbb86', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 225, 2107.7, 1644.2),
('54c80817-ea60-53ab-aa30-e87daa9f6482', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 226, 2110.6, 1643.4),
('43307d0c-489b-502a-86ad-db954320a15b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 227, 2113.4, 1642.6),
('90e08518-8804-5b96-8382-375b70f02952', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 228, 2116.3, 1641.7),
('a9e206f0-c11a-567e-85bb-5b991cb24192', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 229, 2119.2, 1640.9),
('d09db9fb-a8e4-594c-a5f6-221e9a7a86f1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 230, 2122.1, 1640.1),
('fd394264-fbe8-524a-b055-2e9e0d5ed06d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 231, 2125.0, 1639.2),
('a7649f77-a00b-5def-96d2-438c7c198cea', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 232, 2127.8, 1638.4),
('0805d4b6-c721-51a2-ab69-fa58c9c28ca7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 233, 2130.7, 1637.5),
('d2a4764b-e06c-57ff-bc24-5e843fb981c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 234, 2133.6, 1636.6),
('22cc2770-9946-5cde-9467-1172ee9d2644', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 235, 2136.4, 1635.7),
('3cb15665-872b-5797-9ecf-0bbc5b996ffc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 236, 2139.3, 1634.8),
('04c38a65-410e-5f6f-9402-917f2bcd314b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 237, 2142.2, 1633.9),
('147cdcbc-5011-5ba8-b47b-92b59d5bc579', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 238, 2145.0, 1633.0),
('f8d3a551-0b6a-5d77-93f5-5f2d3f1fb35f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 239, 2147.9, 1632.1),
('f075fcea-4aec-5de5-8d90-e43b18f3518f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 240, 2150.7, 1631.2),
('ae48a3e9-afde-577c-96bc-38fc0e0a6b1b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 241, 2153.6, 1630.3),
('43ab5b55-140f-5853-a033-0b1d50fc59db', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 242, 2156.4, 1629.3),
('db552747-f1fb-5bf0-8df9-95acf480d2c0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 243, 2159.3, 1628.4),
('5b965201-545f-5f0d-bf28-88311c338951', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 244, 2162.1, 1627.4),
('12037dbd-c4fb-558f-953b-e8e06c4abe7f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 245, 2165.0, 1626.5),
('5521653b-8e07-5770-a17c-b1a7d30ab0d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 246, 2167.8, 1625.5),
('23ebc659-1be5-5822-8329-e7bba59dc759', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 247, 2170.7, 1624.6),
('ea36939f-d02d-5340-8585-eeb4f4992ef3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 248, 2173.5, 1623.6),
('494cb495-8543-5d3f-ae64-5d61c1bdbf1c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 249, 2176.3, 1622.6),
('ada17756-370d-538f-a913-32ed6312dcd6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 250, 2179.2, 1621.6),
('03cb9211-8db1-5af1-bd55-53a439fe0f8e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 251, 2182.0, 1620.7),
('f952c999-b01f-5de9-9c77-98e9c2854d8d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 252, 2184.9, 1619.7),
('159d8b63-e534-5265-bc1d-e1aeedb7b7ba', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 253, 2187.7, 1618.7),
('969907da-e27b-58ac-a084-19af07e93f02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 254, 2190.5, 1617.7),
('19ba8f46-c700-5c49-ae77-8dffc4c13df9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 255, 2193.3, 1616.7),
('5c723efd-4360-5fa4-b0fb-c80ab01b89be', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 256, 2196.2, 1615.7),
('36613583-df2e-5f77-bba3-bf3b327dd5e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 257, 2199.0, 1614.7),
('2201f04e-a55f-503c-870b-41088878a82e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 258, 2201.8, 1613.7),
('5b1c9246-19e1-5f8e-bb55-c9c8b59898cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 259, 2204.7, 1612.7),
('c600a3b6-e0f7-5ff0-b784-90616c5bc734', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 260, 2207.5, 1611.7),
('e3d730ac-b1cf-5479-b69b-e2f076d58019', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 261, 2210.3, 1610.7),
('ad72260f-2e35-52e8-973d-c27835a1e38b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 262, 2213.1, 1609.7),
('61fd899d-94d2-58b9-8701-2a14894a9bcf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 263, 2216.0, 1608.7),
('eaedabc9-8636-58a9-b8e0-8b25fc8b6e83', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 264, 2218.8, 1607.7),
('f0235ce7-324e-5072-91f6-3e617ea04036', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 265, 2221.6, 1606.7),
('eafb3881-82e8-5646-876b-3c9df3018276', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 266, 2224.5, 1605.7),
('61bffacd-305e-55c4-8b0a-bb61fc0da941', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 267, 2227.3, 1604.7),
('d46f01fd-0226-502d-b0cc-b2d15f50c5fe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 268, 2230.1, 1603.7),
('702ff69d-3392-51f6-b164-28c81cb6fd85', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 269, 2232.9, 1602.7),
('f9bb2651-b8a6-5789-b580-0bdf9967c2ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 270, 2235.8, 1601.7),
('2b31f127-0d57-5540-baae-7bb5fa490887', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 271, 2238.6, 1600.7),
('d785fe47-5c15-50bd-9069-19ececdbebdb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 272, 2241.4, 1599.7),
('8863f59e-b56e-5216-ae41-41283f59abe7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 273, 2244.2, 1598.6),
('0975eb62-badf-5aef-9a43-43d0b0e675e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 274, 2247.1, 1597.6),
('19a0c78b-0787-5d77-9c8a-b7508e8a5043', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 275, 2249.9, 1596.6),
('6882deb1-eb01-5d6e-adc1-20effa870103', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 276, 2252.7, 1595.6),
('63a309c8-e746-5222-bd78-bd9b9bd47181', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 277, 2255.6, 1594.7),
('a1be07b0-79d5-5144-b852-7ec72e72570a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 278, 2258.4, 1593.7),
('b72b4391-1f28-5377-9614-7a673d10abe7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 279, 2261.2, 1592.7),
('5effe5e5-9590-52a4-b0d8-d67229851e14', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 280, 2264.0, 1591.7),
('fa9e4a62-f2a5-5073-84b3-d89835f53af2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 281, 2266.9, 1590.7),
('1b1e5168-0bde-5d61-a4c7-a839a6c6fd25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 282, 2269.7, 1589.7),
('4ed72b82-2b3b-5860-9b5f-6f7fc827184f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 283, 2272.6, 1588.7),
('73f3a907-d6d8-5e76-9e29-6a21c4b045ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 284, 2275.4, 1587.8),
('92661b16-e2b0-5860-a38f-7b63a08286bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 285, 2278.2, 1586.8),
('c6f89585-2dfd-55a7-bdbf-4a0a05dbba24', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 286, 2281.1, 1585.8),
('8cb09530-c7ba-5a8a-965a-936f47a37192', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 287, 2283.9, 1584.9),
('b538a16b-80b4-5cab-9070-46fd180ea861', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 288, 2286.8, 1583.9),
('666d57e3-6a21-5976-ae22-09facaa7b54f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 289, 2289.6, 1583.0),
('117637a0-8f3c-5d3c-8441-3eb0986f8d2d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 290, 2292.5, 1582.0),
('07a2b09b-bb7b-5b2f-8773-1b975f6113fe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 291, 2295.3, 1581.1),
('f6ea46cc-4fb8-53bb-baad-a9a689bbd186', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 292, 2298.2, 1580.2),
('1297f10e-e11c-54db-ae1c-0d3895e5eb40', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 293, 2301.0, 1579.2),
('a3873e6b-65b0-54fe-9caf-26dc4e640539', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 294, 2303.9, 1578.3),
('d82571f1-2179-5a7f-8015-249ace063dcb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 295, 2306.7, 1577.4),
('66cfcb59-43ba-53ef-8d1b-166657d97b0c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 296, 2309.6, 1576.5),
('59435e01-2080-5273-9dc8-5a0d7a29dc8d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 297, 2312.4, 1575.6),
('9101e703-40ea-5ab6-817c-141cbfa7d216', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 298, 2315.3, 1574.6),
('d30af7af-b432-5150-95d8-ecda07126315', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 299, 2318.1, 1573.7),
('38f854c9-d22a-5d2d-98a3-b5cca282547e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 300, 2321.0, 1572.7),
('6ba08c63-24d0-5c42-b3e9-e036d5083af7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 301, 2323.8, 1571.8),
('76ef5aee-ef08-5cf6-bcee-2722535ea6e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 302, 2326.7, 1570.8),
('c00cedc4-2fb6-5092-bb99-24c7da0c8d22', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 303, 2329.5, 1569.8),
('9e2143eb-1a1b-548f-835b-5a853f5e03c5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 304, 2332.3, 1568.8),
('53044d56-d8b5-5337-8239-de126a094da1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 305, 2335.2, 1567.8),
('d175b97a-4f24-506e-989a-6a867666ccb0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 306, 2338.0, 1566.8),
('a6f43e79-22e9-5a54-83c9-63853e1d8d90', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 307, 2340.8, 1565.8),
('5967f24f-99a9-5e8b-b7dd-73cd2dda30e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 308, 2343.6, 1564.8),
('df04a051-c9c1-530e-b8cd-c67e1ac824ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 309, 2346.4, 1563.8),
('1311000a-1532-5315-824f-73dcc21ae045', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 310, 2349.3, 1562.7),
('4e18ac05-5cbb-5269-9813-425602a3d896', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 311, 2352.1, 1561.7),
('43d0d992-a39a-506b-b2bf-ff089e173542', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 312, 2354.9, 1560.7),
('aede5a7b-6a66-516b-9038-be900ed8dd41', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 313, 2357.7, 1559.6),
('3f6691b5-27f9-517e-ac54-6f840894ad9a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 314, 2360.5, 1558.6),
('a8e08857-9156-568a-ae0d-1a9092c2be44', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 315, 2363.3, 1557.5),
('770773ba-2f26-5922-94ee-f6c71901c143', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 316, 2366.1, 1556.5),
('bc57bde2-5b64-551e-a12f-c0be2313f511', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 317, 2368.9, 1555.4),
('c1f40494-3f53-5f00-8df5-0e7c3eb93fa7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 318, 2371.8, 1554.4),
('96cbc337-940e-5d04-9219-a620cd9d730b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 319, 2374.6, 1553.3),
('6771fde7-9ddf-55e3-adb0-de261e1836a3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 320, 2377.4, 1552.3),
('31b98062-466f-5f77-804f-76daafebca22', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 321, 2380.2, 1551.2),
('6a0766e0-9aef-5e58-9c02-5fa429b72231', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 322, 2383.0, 1550.2),
('7ec7837d-260f-5563-9cad-d4e7ff778e55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 323, 2385.8, 1549.1),
('cf7ea319-9de3-52f2-a834-3d7ca0aea81b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 324, 2388.6, 1548.1),
('4a21eec6-b9fd-5b94-913c-091ee6d68fd6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 325, 2391.4, 1547.1),
('be6c06b0-e602-59ea-944a-66801418b6e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 326, 2394.3, 1546.0),
('083be560-a7b6-5edf-8d95-a8b72b154c91', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 327, 2397.1, 1545.0),
('a5873d53-651d-57c3-86ca-8dad563cb7da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 328, 2399.9, 1544.0),
('347301f2-f2d9-5714-bdc4-48e7127cc0a4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 329, 2402.7, 1543.0),
('ddd20b6e-0a82-5722-84ff-20315d943656', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 330, 2405.6, 1542.0),
('c17e9f5c-5beb-5b02-8a5c-7f76eb9d4f81', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 331, 2408.4, 1541.0),
('86194b64-5c38-5c0a-80e9-38a3f4f4caf5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 332, 2411.2, 1540.0),
('ed4e7ce2-668e-5823-80a1-ef89a23fb9bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 333, 2414.0, 1539.0),
('31621d17-15e1-50af-9b8e-59210ade890a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 334, 2416.9, 1538.0),
('3a14d93f-9630-5a89-973c-b2ea3d8ddf86', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 335, 2419.7, 1537.1),
('39920251-9be8-53cc-8ad2-ed1f75347e25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 336, 2422.6, 1536.1),
('063a7756-d300-5af7-9ec0-1c3219b56862', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 337, 2425.4, 1535.2),
('a7b889fa-c8cc-5158-aa66-dd0ce2d91184', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 338, 2428.3, 1534.3),
('4c2c045e-2136-5ca8-8217-2930a28caf68', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 339, 2431.1, 1533.4),
('0b7cc2f9-e523-5d61-8086-d2791d2c920d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 340, 2434.0, 1532.4),
('12af32a7-ef0f-544c-9cb3-9eeb9cd0620b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 341, 2436.9, 1531.6),
('ad04f6ab-27eb-5632-8f4f-bdaf1341a459', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 342, 2439.7, 1530.7),
('e20f6eb7-1f6e-5f6e-a5b8-c28d28663b10', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 343, 2442.6, 1529.8),
('96bb73fe-b32f-5175-849d-754fbc8be0ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 344, 2445.5, 1529.0),
('e1901670-d184-5c80-829a-a3147766a80d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 345, 2448.4, 1528.2),
('289ea1d3-a0cb-5768-99e3-8c6809b2f87d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 346, 2451.3, 1527.3),
('5127acf0-f1b3-5f73-b305-b9fafc379d35', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 347, 2454.2, 1526.6),
('8f18191e-93da-5aa1-90e8-f5006ccab847', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 348, 2457.1, 1525.8),
('cd249ffe-1b88-57ea-b321-d3d24be009ec', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 349, 2460.0, 1525.0),
('c1209825-51e7-5a70-a73a-46c121695300', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 350, 2462.9, 1524.3),
('e35364a6-5cc7-565d-a752-71854a459863', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 351, 2465.8, 1523.6),
('29a9cfc0-225a-5ff4-9709-05047cd1bf87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 352, 2468.7, 1522.9),
('f9a982a0-1ed2-56ff-a039-755e40f82333', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 353, 2471.6, 1522.2),
('8faa39b8-5718-5b00-8c43-e8410ea512a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 354, 2474.5, 1521.6),
('dc2d08e1-f6f0-5434-a0b4-eae236e50a16', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 355, 2477.5, 1520.9),
('98a838af-6706-556c-ba09-faa65e2eac1e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 356, 2480.4, 1520.3),
('a0089d2e-2c11-5ba6-a540-c2eb6ffa631c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 357, 2483.4, 1519.7),
('27ad2d63-4875-5198-b609-1aebffb90612', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 358, 2486.3, 1519.2),
('cd16e542-255c-5485-8e1c-07ae237b95af', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 359, 2489.3, 1518.6),
('0f765f19-b4b8-56ed-aee9-c8c3e43e90a1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 360, 2492.2, 1518.1),
('32097c93-ff70-5ab6-8da7-e4418466aef4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 361, 2495.2, 1517.6),
('413bbaf5-caf9-5a80-b00d-2511a6eecfc1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 362, 2498.1, 1517.2),
('8d469b3d-a9f9-5afd-9d6e-8233649bd19a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 363, 2501.1, 1516.7),
('c705eb64-a156-588a-85ec-de6f890cc752', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 364, 2504.1, 1516.3),
('df851f3f-bfb3-5443-be5b-c1996a95a21a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 365, 2507.0, 1515.9),
('d689ddf4-90e1-5079-9ce5-521112bd49fd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 366, 2510.0, 1515.6),
('942a1fdc-65e4-54ae-8b1c-c09d7d1a3612', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 367, 2513.0, 1515.2),
('99f4769d-a662-5647-bd63-f2435fe22680', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 368, 2516.0, 1514.9),
('ca561e58-ac66-5286-a258-308938d24a5d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 369, 2519.0, 1514.6),
('64801216-c909-558e-87b3-e12249be0356', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 370, 2522.0, 1514.4),
('39bdae39-6616-52dc-a5fc-a396b18cde3e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 371, 2525.0, 1514.1),
('7724d3f8-9039-5c25-985f-5766ff1a9f84', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 372, 2527.9, 1513.8),
('caf5f410-3b08-570d-bc6d-656fc3808f83', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 373, 2530.9, 1513.6),
('e362d67e-c942-5e2a-9825-481608824256', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 374, 2533.9, 1513.4),
('687b6020-852e-5858-a17c-8882203f7890', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 375, 2536.9, 1513.2),
('c3bdba0a-6483-5e32-966f-fcd4fa8164d1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 376, 2539.9, 1513.0),
('d64bf1b8-ded8-5b5d-86d9-c962e700dc2b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 377, 2542.9, 1512.8),
('4b82cb2e-0301-5099-81ee-0e2a18542c80', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 378, 2545.9, 1512.6),
('259a4a9c-dcd8-55b7-b115-334a82b9995b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 379, 2548.9, 1512.5),
('c7ca2fcd-c12f-5da7-9395-18b48a5dba28', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 380, 2551.9, 1512.3),
('3a95e3b5-d681-56e0-aa66-bb49cc077a81', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 381, 2554.9, 1512.2),
('6e36d477-d682-558e-a7b0-704433244c51', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 382, 2557.9, 1512.1),
('531714ae-cff8-53e7-9814-0b80108c3869', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 383, 2560.9, 1512.0),
('cdace464-49fc-5808-9a54-d11a519a9a15', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 384, 2563.9, 1511.9),
('f52a7f20-035a-5826-8978-3c9adbb208c1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 385, 2566.9, 1511.8),
('50c9ea1d-adc2-54f5-8207-ea4c5c4eebe5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 386, 2569.9, 1511.7),
('75bba482-c14d-56b9-a104-f13afb60379b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 387, 2572.9, 1511.7),
('2903b7d0-0868-545b-aa7d-2ac82b6a6ac9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 388, 2575.9, 1511.6),
('6382dc9e-c492-5c48-9be8-30bbbe25b271', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 389, 2578.9, 1511.6),
('b33244d5-e883-56c3-8d84-41c52a1504c0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 390, 2581.9, 1511.6),
('a9b4d91b-2c50-52dc-9d8b-063b8364f23b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 391, 2584.9, 1511.6),
('719783df-a2a5-5e33-a886-f759d0f35f02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 392, 2587.9, 1511.6),
('016e011d-3144-59ca-a2dd-a99c679fa95b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 393, 2590.9, 1511.6),
('cb445c81-51e7-51a0-be54-a19efbd35e74', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 394, 2593.9, 1511.7),
('36956ea0-346b-5b1d-b0d8-f7110779d38b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 395, 2596.9, 1511.7),
('a6d8bcc4-e0fb-5ccd-8aa6-9a7c0bee1c1c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 396, 2599.9, 1511.8),
('a2a7a875-14aa-5f58-8aa1-21ecf8e6ec0b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 397, 2602.9, 1511.8),
('4b2d9666-8bac-5908-a585-4901d6f94160', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 398, 2605.9, 1511.9),
('642676f9-e8b7-5d45-a6ea-e1d3d25bf8ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 399, 2608.9, 1512.0),
('c906cb93-bb82-5de3-a513-bb02f51db6e8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 400, 2611.9, 1512.1),
('4ddf173b-3e4f-5dc7-b9e0-378fca6989be', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 401, 2614.9, 1512.3),
('73f2d1a5-dce5-5335-95e8-46617fa6e084', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 402, 2617.9, 1512.4),
('e328b5c8-8865-50d3-85ba-45707704686a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 403, 2620.9, 1512.5),
('af6d3f53-42dc-58ce-994a-03922008a8a8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 404, 2623.9, 1512.7),
('db25e814-4fe7-5b87-a3e8-1f0f4c4da661', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 405, 2626.9, 1512.9),
('f511fd06-8812-5968-a369-02ccba5f10e8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 406, 2629.8, 1513.0),
('57cd4cff-ba19-5db8-b682-d5669412a8bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 407, 2632.8, 1513.2),
('200a6b14-e71e-53c2-a351-a0417ee2e8c9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 408, 2635.8, 1513.4),
('dbb27875-4eb3-5049-81e0-b883aab6c56b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 409, 2638.8, 1513.7),
('cc01ed68-26ee-5e63-9dbb-e9aee5e23005', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 410, 2641.8, 1513.9),
('238cbbaa-783a-5a03-96cc-5aab13f110ac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 411, 2644.8, 1514.1),
('f31be18f-d446-5bb3-adad-82990162a612', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 412, 2647.8, 1514.4),
('c3049af7-519a-5c1f-991a-05a33851dd0d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 413, 2650.8, 1514.7),
('5994d298-272c-51bc-b2c1-6e978e9edec7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 414, 2653.8, 1514.9),
('31dc2c7f-cdee-52a5-8b16-4724caf4ef98', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 415, 2656.8, 1515.2),
('ef17e982-44f6-555e-b039-5463b9a38fd2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 416, 2659.7, 1515.5),
('49df9509-7921-5405-acaf-e5c6ac643f50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 417, 2662.7, 1515.8),
('d1cc5fd6-340a-5b39-9b49-f6a5b4547986', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 418, 2665.7, 1516.2),
('7079ea0c-da6c-5e35-a529-8fd4e759cdd7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 419, 2668.7, 1516.5),
('d7166c99-66f2-544f-8ca0-88d8e0216272', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 420, 2671.7, 1516.9),
('73994252-513b-5ff9-9bc5-2860c28f9f54', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 421, 2674.6, 1517.2),
('21432cd3-cd0b-540b-8131-90a3caf25f20', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 422, 2677.6, 1517.6),
('4e92363a-a76e-50cf-82d1-7018d7a1b19f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 423, 2680.6, 1518.0),
('f7b09347-0626-590e-9ab1-828d4b07bcaf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 424, 2683.6, 1518.4),
('6daf6d5e-784d-5d79-9680-4c74b29b1c39', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 425, 2686.5, 1518.8),
('ced91323-8522-5942-b6ba-d80973739ec5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 426, 2689.5, 1519.2),
('3b9a4c25-4f37-50f0-b681-9d64cb0b58cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 427, 2692.5, 1519.7),
('b635a299-7b4e-568b-a883-60e733e51285', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 428, 2695.4, 1520.1),
('eab4f7f9-0e4a-5c47-949b-b845c1940c83', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 429, 2698.4, 1520.6),
('ff711adf-ac09-5d39-b282-b61a6aa177d5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 430, 2701.4, 1521.1),
('8362c140-1872-5e27-8fe1-b07f77c8af37', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 431, 2704.3, 1521.5),
('51a20188-15ea-50fe-8d09-50fffad67a22', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 432, 2707.3, 1522.0),
('c455f2a4-3905-5b6c-a8f7-d2fcaedb42cf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 433, 2710.2, 1522.5),
('2900740a-bd6e-5798-b1c6-96c53385c8d6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 434, 2713.2, 1523.1),
('99d097ce-ac92-5521-8e5d-cc8c2b4e89a8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 435, 2716.2, 1523.6),
('a2db5b23-778f-5734-af07-37ad3dd925b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 436, 2719.1, 1524.1),
('9ea9f00e-5dd5-5726-b7e8-8ec53ce20e92', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 437, 2722.1, 1524.7),
('2e42328e-e151-56e4-b2ea-c434d5e63353', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 438, 2725.0, 1525.3),
('fafc2788-4b75-5973-88c9-1d62cc5b19ff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 439, 2727.9, 1525.8),
('be79f0cc-0b4c-5e2d-8b35-8a7ebfd60021', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 440, 2730.9, 1526.4),
('acb0dac9-4a54-5365-b2ca-5e6239798a7e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 441, 2733.8, 1527.0),
('8584670b-1a33-5009-a5d9-250091e3754c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 442, 2736.8, 1527.7),
('1445525e-0f6b-5d7b-b10d-3753981e429f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 443, 2739.7, 1528.3),
('c9c1d7d4-5f2b-540f-bc27-deff16374ee2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 444, 2742.6, 1528.9),
('30e03839-8500-53a4-a286-05242b2dbed5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 445, 2745.6, 1529.6),
('f2372ebd-81df-5ee1-8674-63092772266c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 446, 2748.5, 1530.2),
('e6daae97-d049-51ac-8fa1-b3d5e9075ea8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 447, 2751.4, 1530.9),
('b18dc090-6fc7-56d4-9e81-40041a93edb0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 448, 2754.3, 1531.6),
('d93e5dde-38a8-547c-8120-403a5b0548e8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 449, 2757.2, 1532.3),
('a125e0c2-806f-5f20-a43d-a3cf7c69cc80', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 450, 2760.1, 1533.1),
('346011c2-9d10-5fc1-9f2d-5597453907ac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 451, 2763.1, 1533.8),
('e370efa0-c345-5e97-8097-fdc4287f7105', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 452, 2766.0, 1534.5),
('b4805bb2-a1a8-5ea5-83eb-87245a286744', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 453, 2768.9, 1535.3),
('cdba75f0-aaf4-50d8-bfc4-c087bc73de69', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 454, 2771.7, 1536.1),
('78f5ddb6-dd09-5890-afbc-3abb5df71ebb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 455, 2774.6, 1536.9),
('0fb09d03-10ab-5198-bc06-1ea8d23f6c70', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 456, 2777.5, 1537.8),
('7d3511f9-22ec-5fa7-80aa-b598d60ee22c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 457, 2780.4, 1538.6),
('6744ae22-ed12-5a95-a712-3080f53b9bf1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 458, 2783.3, 1539.5),
('c9a5305e-5d8e-50f1-919f-8ab9f764381e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 459, 2786.1, 1540.4),
('dfbd6256-7d5f-5063-b036-729e752dfb97', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 460, 2789.0, 1541.3),
('29cabe73-9ca5-5cad-97ab-c86d9ef24838', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 461, 2791.8, 1542.2),
('8c339064-d2a6-5c1e-bb0e-f700fa1972ce', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 462, 2794.7, 1543.1),
('69072a90-b87a-5402-8cf6-3552207e7fc9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 463, 2797.6, 1544.0),
('9a44e4a8-ba26-5ee7-b9c7-f2d7ff513c2c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 464, 2800.4, 1545.0),
('bb6bf678-bd02-5ec8-b4bf-d2e41558ef30', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 465, 2803.2, 1546.0),
('027168ed-25e8-55b2-9f51-d7d163ebde35', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 466, 2806.1, 1546.9),
('32f76bbb-f4d9-5648-ab26-26f933b52666', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 467, 2808.9, 1547.9),
('51755636-14f0-5db8-b45b-a9edddb5523a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 468, 2811.7, 1548.9),
('45fcec85-0f84-56f4-91bd-adbf917f7b30', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 469, 2814.5, 1550.0),
('10bc8efc-be4f-535d-a269-48a74d18fa54', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 470, 2817.4, 1551.0),
('2b1117b5-4781-578d-88dd-8b699509f4f2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 471, 2820.2, 1552.0),
('98debc8e-31dc-5190-9d00-e37af7b52636', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 472, 2823.0, 1553.1),
('1ea1d215-456c-5645-a567-a7c9f3b394ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 473, 2825.8, 1554.1),
('7e615d2d-e56d-5f36-b1ff-0cd3f5a524d5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 474, 2828.6, 1555.2),
('c724edd6-1311-5d92-9791-b5420ebe9b2c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 475, 2831.4, 1556.3),
('25613856-302e-54e6-b388-7582224ef71a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 476, 2834.2, 1557.4),
('1034a8a9-6b99-5d6e-b271-ba72e766b645', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 477, 2837.0, 1558.5),
('ed0db242-9cd4-5bf9-841d-4c913b20c6a8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 478, 2839.8, 1559.6),
('2f6308b9-114c-5228-ab9f-c1e1160490ea', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 479, 2842.6, 1560.7),
('d5c983bf-8ec2-56bb-a714-8d9d04a76dad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 480, 2845.3, 1561.8),
('42ef6dce-2808-5632-a976-b700e16cbeed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 481, 2848.1, 1562.9),
('50b0d1f2-e833-552e-ab92-cdea52f06707', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 482, 2850.9, 1564.1),
('f293588b-eb23-5071-b1e5-9074f88fd213', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 483, 2853.7, 1565.2),
('1d972e89-1520-50a1-a197-8113fd0202b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 484, 2856.5, 1566.4),
('b71f2c10-6241-5421-8b5f-34eb8818b604', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 485, 2859.2, 1567.5),
('33b4beec-9d01-5677-8e96-fe2c4e5a255e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 486, 2862.0, 1568.7),
('c9a07a4c-0c07-50fb-bdaf-f3fde9338b07', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 487, 2864.8, 1569.8),
('b51bf371-760c-57c0-80fc-ca6b52d69a52', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 488, 2867.5, 1571.0),
('c6897f9e-38c6-5995-9480-202408279a46', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 489, 2870.3, 1572.2),
('43ca5bc3-73c1-5a23-8f4f-0b41bb0a79dc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 490, 2873.0, 1573.4),
('2e0e9750-0af9-5708-97cf-769c143fe35e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 491, 2875.8, 1574.6),
('f12907dc-a028-5ba1-a48f-9df111756c59', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 492, 2878.5, 1575.7),
('c209890d-421d-55d4-bb00-9cac807d7457', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 493, 2881.3, 1576.9),
('b5de1606-89d1-5838-acdc-45e219362181', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 494, 2884.0, 1578.1),
('76fe48c9-318c-52e0-8a92-f08844e19b18', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 495, 2886.8, 1579.3),
('d913c66a-bfed-5ec2-927d-5c031442f873', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 496, 2889.5, 1580.6),
('f21321d0-5f36-5bfb-b151-18857b733887', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 497, 2892.3, 1581.8),
('4a0b8347-545f-5cd4-9205-e449356f4962', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 498, 2895.0, 1583.0),
('1511a3cc-331d-58b7-a678-0778195418f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 499, 2897.8, 1584.2),
('c4d21042-6f25-562c-b407-9ad8de695b2e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 500, 2900.5, 1585.4),
('57745efc-8044-5d14-8698-4b84821804b3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 501, 2903.2, 1586.6),
('456719ca-792a-5417-9ddd-ea9b48a7f44e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 502, 2906.0, 1587.8),
('1c43fc9c-66f6-5ca1-a41c-6134889acb4c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 503, 2908.7, 1589.1),
('cc8c5dc3-1b9c-586a-a238-c5d689a4a8a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 504, 2911.5, 1590.3),
('8d6f2b06-3b0e-5508-aa27-f19e7b200c95', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 505, 2914.2, 1591.5),
('e0690fb8-9fe8-52f0-8da7-d708e126135d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 506, 2916.9, 1592.8),
('53c1556c-da77-528f-ab5f-008367e96e38', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 507, 2919.7, 1594.0),
('656045d5-ec87-5613-b40b-ec244d108aaf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 508, 2922.4, 1595.2),
('1b5abeb8-e2df-54b6-ab62-c1d82e0240f1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 509, 2925.1, 1596.4),
('2e4e5321-490c-5471-96d4-4f22ba7f1df8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 510, 2927.9, 1597.7),
('8152b910-ae5e-50b7-92bf-975c76cb9397', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 511, 2930.6, 1598.9),
('73ae60bd-ddad-51f8-a97b-54788bf83ca1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 512, 2933.4, 1600.1),
('a6292765-31b5-50e4-8d7c-77ecef45b66e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 513, 2936.1, 1601.4),
('1d1692cd-300b-5384-a1e9-125a52f6b1af', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 514, 2938.8, 1602.6),
('da82c761-c47c-520f-abab-31c73337c2a7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 515, 2941.6, 1603.8),
('6a9122d9-807a-5747-9bbc-e53fa533bcaa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 516, 2944.3, 1605.0),
('85693055-2abc-53c6-a99b-8bb38d930f88', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 517, 2947.0, 1606.3),
('e9d20042-72b6-58de-99d5-0b082d9a9aff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 518, 2949.8, 1607.5),
('40a7efba-b611-5053-ae47-b275267c0ab7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 519, 2952.5, 1608.7),
('d8b3dde5-ae0e-5ebb-9102-1bc4747e2bb9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 520, 2955.3, 1609.9),
('a84427b3-7919-577e-9220-69243e266c1a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 521, 2958.0, 1611.2),
('db0aeb53-9b75-57ee-9d02-ee6a2d5de198', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 522, 2960.7, 1612.4),
('35d608af-a173-5624-8dca-36e07f6ea748', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 523, 2963.5, 1613.6),
('694ec12c-e6a6-547d-b63e-6f21ad416d87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 524, 2966.2, 1614.8),
('4521a4ef-16d9-56ca-8c01-8b33b044c8b4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 525, 2969.0, 1616.0),
('e0f82b16-6413-5144-860c-e70775ed2d23', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 526, 2971.7, 1617.2),
('7a3f3f44-4d7f-5504-8b1e-4dd598403569', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 527, 2974.5, 1618.4),
('83e5d1ff-1ce3-583c-9518-d300ba129bdd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 528, 2977.2, 1619.6),
('f4197e55-bbb4-56e3-b467-529b856eed25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 529, 2980.0, 1620.8),
('3f73c260-a71e-5b34-a614-2507b79ed577', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 530, 2982.7, 1622.0),
('78604b8d-3b48-53ef-8d8a-6bcff434ebde', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 531, 2985.5, 1623.2),
('4ddba698-1b5a-5345-9805-038d3642912b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 532, 2988.3, 1624.3),
('860c8602-d5c1-5da8-8eb1-871f930bd49d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 533, 2991.0, 1625.5),
('7105eeaf-c4ac-5ca2-a3b7-14527a95dcdc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 534, 2993.8, 1626.7),
('bd428b4e-9a53-508d-bc99-41e365a3abe9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 535, 2996.6, 1627.8),
('37cffd8b-4099-5517-8e1f-2bac047ae2f3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 536, 2999.3, 1629.0),
('f7dda1f2-2f8d-5edb-aabf-6eb34ed02acb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 537, 3002.1, 1630.1),
('527b77c0-32a4-50ad-8f0b-16ada097a67d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 538, 3004.9, 1631.3),
('f48da5d4-a9fd-5d5a-908f-2db64e20aafe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 539, 3007.6, 1632.4),
('9fdf8c74-1bf7-5246-acd8-7c3294c4b1bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 540, 3010.4, 1633.5),
('103f8e8f-4bbc-5337-95e3-523c7d4f3687', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 541, 3013.2, 1634.7),
('3a73ae54-2a80-56f4-a361-cfbf89d67b74', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 542, 3016.0, 1635.8),
('65bdc9c3-086b-588d-b00c-e0db0cf85834', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 543, 3018.8, 1636.9),
('ccc90102-9a32-5f16-96d7-cfcd0f72bc63', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 544, 3021.5, 1638.1),
('c0dd4b33-4732-5d92-8251-41f7fd7ba002', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 545, 3024.3, 1639.2),
('b92cfc50-e25e-5008-8635-cce332dffc2e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 546, 3027.1, 1640.3),
('7c7a866a-9e18-5855-8d51-3bccb89bdba9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 547, 3029.9, 1641.5),
('db91fc7e-9d94-5ac2-a76f-62f1394f829e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 548, 3032.6, 1642.6),
('6f8fbeef-be9f-5976-925d-1f6d58409a59', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 549, 3035.4, 1643.7),
('27652615-e987-5270-8990-827e3042f318', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 550, 3038.2, 1644.9),
('747a8219-4b5d-54a9-b401-f726032f07ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 551, 3041.0, 1646.1),
('d931b5c4-d8b1-5a01-bbcf-576de57a16e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 552, 3043.7, 1647.2),
('a42aa53f-c944-506b-8e58-80af3a41675f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 553, 3046.5, 1648.4),
('2a083892-8ed7-5439-ab83-f00e8d83be27', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 554, 3049.3, 1649.6),
('e868a636-9ed7-5b73-a15f-fb44563a3f50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 555, 3052.0, 1650.7),
('0331ca19-ac46-51b1-95fc-b8339ade7f27', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 556, 3054.8, 1651.9),
('24d068bd-5ff9-5bf7-bd77-1008eb0f16c7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 557, 3057.5, 1653.1),
('ed9c87a9-7403-512c-928f-f142d78fa1ec', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 558, 3060.3, 1654.2),
('83d36224-b5cb-56c4-bdca-b21022a9f50e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 559, 3063.1, 1655.4),
('408b7e68-b23b-53b4-b2bd-4122656b7125', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 560, 3065.8, 1656.6),
('69ecbc0a-f0b3-5e07-a6f4-8597a6ca5514', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 561, 3068.6, 1657.8),
('fe78f115-4154-58f0-b917-907baeda1694', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 562, 3071.3, 1659.0),
('78b9ff83-59f8-5780-84b9-0c2105b7371f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 563, 3074.1, 1660.2),
('1422360d-c1c2-5bd6-8084-b6fdcc9bc3cb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 564, 3076.8, 1661.4),
('f327ea10-b766-5d0a-bcb2-232dd41ce99f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 565, 3079.6, 1662.6),
('9b208dde-83e1-5369-98cc-3512fe040c69', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 566, 3082.3, 1663.7),
('07bc741a-73a3-5dbb-9a48-181bfc083057', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 567, 3085.1, 1664.9),
('68683c2b-604e-5b77-8b19-92b891ab544d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 568, 3087.8, 1666.1),
('384311f9-7f1c-5471-86e1-583824e6c373', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 569, 3090.6, 1667.3),
('16e37217-0bdc-5d4d-9fb9-3a0fd0d19122', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 570, 3093.3, 1668.5),
('556bfec1-aea8-5338-b57b-edc1414b0923', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 571, 3096.1, 1669.7),
('06c16f40-06ed-58a6-b864-89b85c3ffe7e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 572, 3098.8, 1670.9),
('99f6dce9-61af-5647-a238-1d54239ced4d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 573, 3101.6, 1672.1),
('c893903f-588c-5a82-8a1e-f49b7e673653', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 574, 3104.3, 1673.3),
('13c97479-e899-553c-b476-d12c27fcd09e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 575, 3107.1, 1674.5),
('3e78854f-0e6a-5002-8a0b-03078405e4f8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 576, 3109.8, 1675.7),
('e3295958-c388-532d-bc1c-631eed76719b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 577, 3112.6, 1676.9),
('10e1d101-4679-595d-8083-ba9a35727ac1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 578, 3115.3, 1678.1),
('d67d0a14-0402-572e-a9ed-140be5e6cbce', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 579, 3118.1, 1679.3),
('a9faf528-bbb3-57d1-9d11-32b09cbdfe89', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 580, 3120.9, 1680.5),
('64660b46-bfad-5e10-bfdb-b857c824630c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 581, 3123.6, 1681.7),
('b4b1a240-5451-55ac-ad10-032bd87eaf33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 582, 3126.4, 1682.9),
('5fab7947-8899-5a1d-97bc-8faa904f0ae5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 583, 3129.1, 1684.1),
('1f72c14e-2658-5ab7-8363-f0965f9ca82b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 584, 3131.9, 1685.3),
('79fb746f-07a9-534a-aee8-8a93c4fce3e7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 585, 3134.6, 1686.4),
('62cd3c4c-58a4-51fb-9379-30662ccb8dd0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 586, 3137.4, 1687.6),
('8f27081f-bc0b-5de9-ba88-b02dce261e12', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 587, 3140.1, 1688.8),
('ae10c4e2-9b21-5fcf-9487-2e28967f498c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 588, 3142.9, 1690.0),
('00b84f75-7bf5-56db-91c3-92cc2f6e72dc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 589, 3145.7, 1691.2),
('34ec1e0a-a3a7-513f-bea5-052f414f57bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 590, 3148.4, 1692.3),
('9f3852f1-feba-5004-9e18-64a42a64232a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 591, 3151.2, 1693.5),
('b6c7d6ab-1db4-565d-8bde-5dae12004a11', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 592, 3153.9, 1694.7),
('9de4bd3e-6f83-57b3-8142-bf10b2e6a2fb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 593, 3156.7, 1695.8),
('ef076603-7f6a-5cb4-9e73-3237c6d0854a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 594, 3159.5, 1697.0),
('60495fbb-73d7-58b8-95f8-ef57c0aa56a5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 595, 3162.2, 1698.2),
('4bb0a022-9366-592f-b025-da04e28df562', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 596, 3165.0, 1699.3),
('1d629b54-924e-577e-9a55-3d5daa2ff49f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 597, 3167.8, 1700.5),
('209a10ff-bffa-5ede-a77f-362e25cc7e21', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 598, 3170.5, 1701.6),
('0f27195b-d80d-554b-a2dc-db8c16549769', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 599, 3173.3, 1702.8),
('fd086985-4907-5af7-8fef-0394b7c8fb60', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 600, 3176.1, 1703.9),
('04388b5d-1895-5b21-88e8-bc53a5b79c76', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 601, 3178.9, 1705.0),
('748ad73c-be1e-5aec-92ec-d962fcefbeab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 602, 3181.6, 1706.2),
('cf4e57ab-b913-55b8-9a6e-f9a37ed5d761', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 603, 3184.4, 1707.3),
('f6875fe7-e0a3-5d3d-80bf-3b481dbe0b81', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 604, 3187.2, 1708.4),
('ef3dd0d8-940e-5118-a5b9-9da054a11f05', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 605, 3190.0, 1709.5),
('40f6eef8-e792-5b10-92d1-3c506d86c71a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 606, 3192.8, 1710.6),
('69832b12-044b-5010-84b9-554499fb7011', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 607, 3195.6, 1711.7),
('491ac21f-a226-5c0b-be8b-d920e7ae0339', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 608, 3198.4, 1712.8),
('80e2ac2a-1bee-55d3-982a-575b429649f6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 609, 3201.2, 1713.9),
('39dc94a3-01e4-5042-b4f6-2fa7d31f50b7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 610, 3204.0, 1715.0),
('3fa94565-44fe-5878-8e8d-90d381311830', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 611, 3206.8, 1716.1),
('80d15be6-359b-5980-967e-1a6f9c3e6a3d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 612, 3209.6, 1717.2),
('6a86d0cd-5b2e-58af-a13c-5510dbda81cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 613, 3212.4, 1718.2),
('0e4f683b-4d98-54c6-b341-3b7b847e4ef3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 614, 3215.2, 1719.3),
('cfb8114e-3d05-503e-8985-87632eccdaf2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 615, 3218.0, 1720.4),
('ca18c157-f5c6-5f1d-b661-ad4a640cbb0e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 616, 3220.8, 1721.4),
('82286f47-997d-54f8-baec-9dcfce75b872', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 617, 3223.6, 1722.4),
('b74277b4-2b5f-523b-9f22-adf7c97d468d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 618, 3226.4, 1723.5),
('4bf1ecec-1e2b-5a7e-8449-b5f288b47ddc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 619, 3229.2, 1724.5),
('71ef26cb-12f3-598e-b8f1-9b68832eed5e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 620, 3232.1, 1725.5),
('7354b8cc-b6fd-52dc-bc53-fe7c68c804bc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 621, 3234.9, 1726.5),
('ee96fa24-871a-5254-a4e3-3db5f65a6bbf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 622, 3237.7, 1727.5),
('e4ebc988-7183-5ec6-8ac8-a63dfdd9100a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 623, 3240.6, 1728.5),
('a2a1956a-5c85-58f7-88a2-54b17df70cdf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 624, 3243.4, 1729.5),
('83e4d4a3-94a6-535f-8e60-142b9c8cbf26', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 625, 3246.2, 1730.4),
('a9595d1c-4821-5319-b20b-9230586107bc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 626, 3249.1, 1731.4),
('2a2d441d-1d6f-5d83-a13a-5a8fc5212a2e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 627, 3251.9, 1732.3),
('24bd2963-de2d-5420-b1e7-41a8260435a0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 628, 3254.8, 1733.3),
('afc27be2-2564-550a-b7f7-21ee42549d3a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 629, 3257.6, 1734.2),
('d8b5d814-de61-538f-ab19-f080b710a316', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 630, 3260.5, 1735.1),
('56a94be8-62c0-5ea4-9a65-b6ab5a9bdba8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 631, 3263.3, 1736.0),
('802655f0-5b56-50ad-baf5-885b9d055861', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 632, 3266.2, 1736.9),
('07f99593-0e20-5f76-a614-b8ca5f60a8fc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 633, 3269.1, 1737.8),
('17a40d15-e553-58dc-8584-013aad28a437', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 634, 3271.9, 1738.7),
('cf471728-a77e-521d-9a62-41c631da5422', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 635, 3274.8, 1739.5),
('31c6b510-b425-5c5a-9ff3-81ab898f21a3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 636, 3277.7, 1740.3),
('c2a10391-1b06-535a-acc8-d5714dd1d5da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 637, 3280.6, 1741.2),
('64079f9e-9636-5697-b068-dc4bb567e950', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 638, 3283.5, 1742.0),
('a93de7e1-1994-51d6-bbf2-035399dfc43f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 639, 3286.4, 1742.7),
('12cf761c-1741-5cc2-b4f3-e94ecf86cd72', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 640, 3289.3, 1743.5),
('a70b78e7-e02a-570b-8716-b55490c68feb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 641, 3292.2, 1744.2),
('7c01e2e4-c7b3-53ca-a322-90b0e92f50b2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 642, 3295.1, 1745.0),
('d1020e23-170b-5608-bd18-2199cbbee196', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 643, 3298.0, 1745.6),
('3b4ebcec-4be0-5311-a50a-7818fbb52127', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 644, 3300.9, 1746.3),
('3a44a3ce-6873-59f1-8606-e523cc7458d2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 645, 3303.9, 1747.0),
('7c3953ba-b953-5b62-852b-d6f7c39da4c1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 646, 3306.8, 1747.6),
('76eed937-d0ac-581b-838b-6df7be62afd2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 647, 3309.7, 1748.3),
('ea20a958-8f7d-56f6-a0bd-a3b61e5bbc20', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 648, 3312.7, 1748.9),
('b24c6125-a6b5-54df-b2ee-7039b45c7afe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 649, 3315.6, 1749.5),
('14b2961a-a303-58d3-8cbb-824da1f6e2a1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 650, 3318.5, 1750.1),
('6972bcef-d67b-53d0-a35a-aecf5de97500', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 651, 3321.5, 1750.6),
('4cde3489-fe67-5903-9eb5-603c8a2accdd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 652, 3324.4, 1751.2),
('76045193-1841-5db9-9953-8a2c391fa9ed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 653, 3327.4, 1751.8),
('90eb2fcf-d8fe-5774-98de-e0126c41d304', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 654, 3330.3, 1752.3),
('dfd32907-f80a-54af-82d7-62cfd1746488', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 655, 3333.3, 1752.8),
('30881b39-54f5-5173-bebe-e439a9796731', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 656, 3336.3, 1753.3),
('8b1efa90-213d-5407-882c-7fe4d2547760', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 657, 3339.2, 1753.8),
('927f29ec-ebdb-5eb1-ba88-53240e1562b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 658, 3342.2, 1754.3),
('5f5bc79e-bfed-57eb-98ae-f15ad49e0780', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 659, 3345.1, 1754.8),
('ab461139-eb72-5ac4-bf03-3cca5fca1021', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 660, 3348.1, 1755.3),
('0597589d-6e86-5661-9d74-c33f4910632d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 661, 3351.1, 1755.7),
('b20bff52-7d56-5524-9e1b-b6d6037a3627', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 662, 3354.0, 1756.2),
('a166a7f3-997f-5493-925c-276c2e1d16f4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 663, 3357.0, 1756.6),
('3ef9d53c-5293-5be1-92c2-569c055cd072', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 664, 3360.0, 1757.1),
('a558c0c8-0824-5021-965d-f1c67f6c41cf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 665, 3362.9, 1757.5),
('8b9ec3b6-40c0-5313-90a3-2cd8391520b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 666, 3365.9, 1757.9),
('ba1df500-0762-5fce-a4c7-6eb53f926e98', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 667, 3368.9, 1758.4),
('1a4bdb28-7b1d-5b5d-ae8a-7c56a7ec0392', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 668, 3371.8, 1758.8),
('21fd0e5c-504e-52f4-90b7-f6f2d7de5687', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 669, 3374.8, 1759.2),
('51315e39-4596-5282-860e-c4c17c2b2642', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 670, 3377.8, 1759.6),
('037a1d7f-13b1-54ee-ada2-8b0664d4e8ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 671, 3380.7, 1760.0),
('b0d01d3e-fa28-5c17-a553-d8301b892978', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 672, 3383.7, 1760.4),
('d027fab7-870e-5741-a428-c8aea3afdb98', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 673, 3386.7, 1760.8),
('f7a9fd17-2759-51d1-a492-8d36ac392b9f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 674, 3389.7, 1761.2),
('dd63a3bb-770c-5353-ab2e-ed09c58cca50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 675, 3392.6, 1761.6),
('ee3bc8d4-88a9-5691-8cc6-726387231d12', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 676, 3395.6, 1762.0),
('2d75c138-f1ce-54fa-9cd0-72c62d4a0abe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 677, 3398.6, 1762.4),
('a52ba65f-e8b6-5d8e-94e5-07137e804041', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 678, 3401.6, 1762.8),
('02d6cde2-0ed4-5862-a8db-ecdd9c26a516', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 679, 3404.5, 1763.2),
('9f9211a4-27ab-51c0-bec9-7f9603692ad8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 680, 3407.5, 1763.6),
('b362bbcf-fa52-55bd-b82b-92059742d3dd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 681, 3410.5, 1764.0),
('ff6d9e2b-197b-53b8-b26b-7ba0bbc0f458', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 682, 3413.5, 1764.4),
('891eab6b-73f6-5827-9f11-dd88f77fa21f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 683, 3416.4, 1764.8),
('f4d92c58-b9f3-5f6f-8180-2b7d1bc33f8b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 684, 3419.4, 1765.2),
('3d6584d5-bb00-528e-bde0-7af2365a6192', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 685, 3422.4, 1765.6),
('fea491f4-f0c8-5626-be65-a19ec7de236c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 686, 3425.3, 1766.0),
('f1fd6822-42e3-5353-a11d-b50d9fe03e57', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 687, 3428.3, 1766.5),
('a915a9c7-135f-5f51-9f79-da828cd6ad2d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 688, 3431.3, 1766.9),
('67e471ef-6779-544d-8024-c993e290c81d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 689, 3434.2, 1767.3),
('c95404d6-5136-5911-9705-5df64b0dca21', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 690, 3437.2, 1767.8),
('682bd822-f04a-584e-a843-3790bb013444', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 691, 3440.2, 1768.2),
('a3a1805f-387f-5d86-bbbd-11abbfa9e82a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 692, 3443.1, 1768.7),
('c1b56606-bb58-5040-9ed2-912436d33507', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 693, 3446.1, 1769.2),
('cf63464c-bdd7-5948-9ff3-2b74e5e07813', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 694, 3449.1, 1769.6),
('ce410a57-af03-5a2a-9715-69b426926c85', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 695, 3452.0, 1770.1),
('3f847e7c-8918-5e64-b8e5-cbfb62690bf3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 696, 3455.0, 1770.6),
('a8e9dd35-86ef-5f36-a696-84a50bd86787', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 697, 3457.9, 1771.1),
('efa41543-7d27-5d94-98fc-744f30e3545c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 698, 3460.9, 1771.6),
('525f4380-a09c-5204-971d-901b1f3fe977', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 699, 3463.9, 1772.2),
('b3da3dcc-07dc-5abe-8a07-2a937cf8f10b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 700, 3466.8, 1772.7),
('0ac0a2d9-3a04-52ff-b6c3-e05e770dbe7d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 701, 3469.8, 1773.3),
('ae5a065d-b286-5339-99eb-3ef37648bdc9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 702, 3472.7, 1773.9),
('5e9ee3f6-7614-573c-bd10-94891895030d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 703, 3475.6, 1774.5),
('e5fc3918-7363-5dec-8b1d-2654ef87f20e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 704, 3478.6, 1775.1),
('ef3a68ec-47ef-539d-ada8-1fef02042b18', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 705, 3481.5, 1775.7),
('d3caf0c0-bde0-5d87-a81d-f62ed7dfa021', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 706, 3484.4, 1776.3),
('01a090b4-f775-5715-bd27-c567702de7e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 707, 3487.4, 1777.0),
('98b8a361-8539-5ab1-970e-311d87bdb552', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 708, 3490.3, 1777.7),
('5a1db0c5-d94c-5860-b96d-a03efc154af9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 709, 3493.2, 1778.4),
('be8e438b-0e5e-59a8-839c-a79344182437', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 710, 3496.1, 1779.1),
('27af116e-0f76-51c1-bb30-6282dd85e1e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 711, 3499.0, 1779.9),
('8ddc3dc9-c194-5e99-95f9-898091369325', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 712, 3501.9, 1780.6),
('d19187ef-e745-5fb7-b0e9-f8f7bb262def', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 713, 3504.8, 1781.4),
('401a67e8-b741-533b-9922-11b077e83c0f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 714, 3507.7, 1782.3),
('a6988dd8-db90-57ce-8e89-1623aef98d8f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 715, 3510.6, 1783.1),
('12ffd354-a943-5c01-8701-4e53c221d4f6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 716, 3513.4, 1784.0),
('232fa333-442f-51b7-bcd0-63db5a524a61', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 717, 3516.3, 1784.9),
('027e60c6-e868-5530-9a90-01f00b02371f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 718, 3519.2, 1785.8),
('10785f50-facf-5415-b2cc-7191fea23f54', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 719, 3522.0, 1786.7),
('f0fa3d13-437c-5949-9879-3ef18a92f284', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 720, 3524.8, 1787.8),
('eae2ae5e-c358-5c78-a617-7de1f72b9755', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 721, 3527.6, 1788.8),
('6c5da6a5-a14a-5a9e-807d-5d8030169af1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 722, 3530.5, 1789.8),
('06816fcf-cb9b-5658-a62b-13c0deb668bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 723, 3533.3, 1790.9),
('edfed90e-1c3d-5df9-bcb0-a0ecd441e1da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 724, 3536.0, 1792.0),
('d9d257d0-4be3-561d-9668-4e77f9b9c907', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 725, 3538.8, 1793.2),
('3a1329ac-8db6-54d6-8543-5179c19f7ac1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 726, 3541.6, 1794.3),
('242b6bfc-973d-56f8-b14a-8af2e3669a32', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 727, 3544.3, 1795.5),
('32bf0ded-f5ab-5ff8-bb0b-d450c6fd90d1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 728, 3547.1, 1796.8),
('fb5680c9-e466-5474-91a3-b10e4006f662', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 729, 3549.8, 1798.0),
('ffd2b908-1563-524a-9a61-4efcb4a85e70', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 730, 3552.5, 1799.3),
('29dd0441-585e-571f-b2ad-0bdd1fde4372', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 731, 3555.2, 1800.6),
('5529269c-2969-51b5-90aa-c26ac623474a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 732, 3557.9, 1801.9),
('c0752381-5bd6-55c7-ba8e-b0a146d816d1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 733, 3560.6, 1803.3),
('54effbf2-e2ed-5b8d-a128-c56c4d4a3296', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 734, 3563.2, 1804.7),
('7c9f69a8-12aa-52bf-936d-955851b851b4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 735, 3565.9, 1806.1),
('724a58f1-8bed-5c05-b5c9-12a696d513eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 736, 3568.5, 1807.5),
('563ea4c2-7a33-55df-9ee8-13138e019d85', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 737, 3571.1, 1809.0),
('f9c37cde-df50-5115-91df-9d168d0f277f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 738, 3573.8, 1810.4),
('fbb70544-9885-566f-ab48-6e21d3ddd767', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 739, 3576.3, 1812.0),
('ee5d67e2-738e-5f81-b01e-e75b0519c792', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 740, 3578.9, 1813.5),
('a9ef9d4a-9ecb-5d14-acb3-2bf6d593789f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 741, 3581.5, 1815.0),
('d9bb8bb2-b598-5e43-bef8-d5f33a8c2a10', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 742, 3584.1, 1816.6),
('b36fe0fb-92df-566f-9a21-4f60772a16a1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 743, 3586.6, 1818.2),
('1a51e884-f6fe-587b-b1df-37df42c78d67', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 744, 3589.1, 1819.8),
('fc69a4b0-2436-589c-8fa9-d7a80f4c841a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 745, 3591.7, 1821.4),
('7fca3302-e404-5a75-9406-44c10e52b19d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 746, 3594.2, 1823.0),
('7e878b68-877e-523f-a74e-55557983b87a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 747, 3596.7, 1824.7),
('262b9d05-dff7-5358-8bb1-ba40ecedfe55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 748, 3599.2, 1826.3),
('cb2d4220-0e81-5671-a1e8-92ae77570e21', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 749, 3601.7, 1828.0),
('b0f72c88-6fb2-51e9-8ca9-c4a3fe8d8361', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 750, 3604.1, 1829.7),
('01e7e49b-e6bc-5864-806d-5c831519ff4d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 751, 3606.6, 1831.4),
('310bdba3-35ed-5088-aff3-a57889f8ebb1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 752, 3609.1, 1833.2),
('19277956-e092-51b3-a249-f9e0ae32fe6d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 753, 3611.5, 1834.9),
('ecef1b33-335f-5e1a-a0a7-969f2792f763', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 754, 3614.0, 1836.6),
('eb84290c-8900-5528-947b-e88490feab60', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 755, 3616.4, 1838.4),
('616731b0-5774-5f7f-a8a3-5a6da14416e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 756, 3618.8, 1840.1),
('a6da930e-39ad-578b-8554-44f51f8e54cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 757, 3621.2, 1841.9),
('7b72db5c-ac6d-5525-83b0-41e4487c5812', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 758, 3623.7, 1843.7),
('2312e3fe-05cd-5cc8-aa3d-5937bd2e6429', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 759, 3626.1, 1845.5),
('99d711ac-5f3c-5b4b-abf9-372bf02c7b7f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 760, 3628.5, 1847.2),
('2f1a6b95-d6bd-5732-87c9-de23b34b82e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 761, 3630.9, 1849.0),
('9b38d7b8-d0c6-5d9f-bca4-e127357ed137', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 762, 3633.3, 1850.8),
('37650804-ec04-520a-9da1-a4507874b117', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 763, 3635.7, 1852.6),
('73a0d405-92f1-51ed-b877-2e471f1cfb97', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 764, 3638.1, 1854.4),
('3acd4726-6719-5de8-817f-4faa9b2db92d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 765, 3640.5, 1856.2),
('21ee389d-7950-5a0b-920f-6ca7f1dfe2dc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 766, 3642.9, 1858.0),
('31432c57-442d-5f30-87fc-25ff45d43d24', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 767, 3645.3, 1859.8),
('b1f6722b-65d8-53a0-892c-09c7df8e069f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 768, 3647.7, 1861.6),
('0dddeb9c-1d8e-5b0e-9526-cc59d9f8007d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 769, 3650.1, 1863.4),
('1b52bcf2-69ef-58c0-8022-d583a033767c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 770, 3652.5, 1865.2),
('5d8b7304-890b-55de-b052-e5d7d6d2ad6b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 771, 3654.9, 1867.0),
('56780678-ff09-5762-9175-5ec392208edd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 772, 3657.3, 1868.8),
('fab81121-e601-5ae0-a248-2c800e41b0f8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 773, 3659.7, 1870.6),
('888d9be9-e81c-5f05-a5af-c0c5ad6dbeb7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 774, 3662.1, 1872.4),
('f74c213a-a7f0-5ef1-9c24-b2ef16f9dee1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 775, 3664.6, 1874.1),
('5f4338fb-f259-5e4b-bf0a-5162b214a8e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 776, 3667.0, 1875.9),
('41530626-d2d6-5ddc-a708-5e4da5d2ce8e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 777, 3669.4, 1877.7),
('30719b5b-27e3-508a-9942-7e845d2d00e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 778, 3671.9, 1879.4),
('692afae7-b427-5718-ba9c-0f6b0c3ac0d8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 779, 3674.3, 1881.2),
('66688e6c-ad61-5906-b146-02558487c393', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 780, 3676.8, 1882.9),
('7a7eb053-e83a-5dfb-a9a6-719de69111c1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 781, 3679.2, 1884.6),
('ab712efd-ea7e-5a77-a8e8-bd096953a107', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 782, 3681.7, 1886.3),
('f812d330-02e9-5c6d-897c-fadcc594600d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 783, 3684.1, 1888.0),
('9768ce13-2b2c-55d9-90f9-0dd9819eed33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 784, 3686.6, 1889.7),
('e38878d9-2718-5880-98dd-2950ee5daa9c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 785, 3689.1, 1891.4),
('e241ec65-5aa7-57b4-88ec-1151f6565ef5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 786, 3691.6, 1893.0),
('23b44663-9add-505f-9108-bd163faedbad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 787, 3694.1, 1894.7),
('3957ca19-02bb-573c-8eeb-2228fbfa380f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 788, 3696.6, 1896.3),
('3ec624c2-9488-51c3-9320-b780d7c964e2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 789, 3699.2, 1897.9),
('d4ff20f1-d458-574e-bee1-80e28d63eaf1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 790, 3701.7, 1899.5),
('8436e407-45c3-5395-8ab7-d28b688cc7e6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 791, 3704.2, 1901.1),
('6ea1fcd5-ee33-523a-b365-32e0a7271a55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 792, 3706.8, 1902.7),
('d346e028-2eeb-5187-b40a-767aad3c9584', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 793, 3709.4, 1904.2),
('efc3f279-c423-5df8-ad7c-1861a0b3daf2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 794, 3711.9, 1905.8),
('6a39fb00-d332-5f13-8aa9-1ae202fa75cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 795, 3714.5, 1907.3),
('83b1bf52-edf5-5d77-b963-1451fb2c3410', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 796, 3717.1, 1908.8),
('b16d25ff-ff4b-527a-8047-2c48fad87e5f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 797, 3719.7, 1910.3),
('501e6210-d9a3-5ec9-8b9d-5979220c1fd2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 798, 3722.4, 1911.7),
('d1e7bd77-afc1-5698-8113-3d63f07e2dca', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 799, 3725.0, 1913.2),
('c27b1921-dbc0-5112-9aec-8788bbd1c293', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 800, 3727.6, 1914.6),
('504c1edb-c775-5d02-94c9-51593fbcdfc4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 801, 3730.2, 1916.1),
('54cd1847-9bc4-5426-b378-6bfb2817b57a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 802, 3732.9, 1917.5),
('79681f37-1af9-57f6-ac74-aced744e1ef7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 803, 3735.5, 1918.9),
('a563a071-d4ef-56ad-bdf4-a62184eaafb5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 804, 3738.2, 1920.4),
('f3d3ad90-816c-5791-bc03-a732ec5731bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 805, 3740.8, 1921.8),
('d4e18a4a-c608-5c67-8292-0a46d765e0ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 806, 3743.5, 1923.2),
('8e49ee0d-875d-5d11-a058-8df11bb33d1c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 807, 3746.1, 1924.6),
('719ecf4a-c587-5df3-881f-7e48c675d4d2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 808, 3748.8, 1926.0),
('b66a5d1b-c163-5f6e-8d33-4c1ec1ec6908', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 809, 3751.4, 1927.4),
('39ac92ec-b2d7-59b4-8c12-659a30b97c9d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 810, 3754.1, 1928.7),
('7bec936a-e8bb-51de-9d0a-b9452b001edb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 811, 3756.8, 1930.1),
('7dedb18f-615f-5146-87dd-bce0de39071e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 812, 3759.4, 1931.5),
('c5f4eeae-1d3b-557f-81ac-ed88165aa395', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 813, 3762.1, 1932.8),
('56844443-c0ec-54fb-8f9f-50418ac9fe07', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 814, 3764.8, 1934.2),
('252d2f2b-3420-52b9-b55f-a392f742fc50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 815, 3767.5, 1935.5),
('c2a02973-677a-5ecc-8113-fd3ca569a787', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 816, 3770.1, 1936.9),
('8c36b389-5cb2-5992-9948-7fccab374157', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 817, 3772.8, 1938.2),
('c83729dc-a9b3-5197-8c6a-44c2af34029c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 818, 3775.5, 1939.6),
('6dba1dce-8e17-50de-a037-92d61a909570', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 819, 3778.2, 1940.9),
('bff0c204-6010-5ac7-bd33-107b07d8913d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 820, 3780.9, 1942.2),
('c4c860dd-04d7-54c3-8d7a-b7cd3dca121a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 821, 3783.6, 1943.6),
('1869e073-6d41-5dec-949b-1bbe5df04cda', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 822, 3786.3, 1944.9),
('d624849b-d42a-5946-9ef9-6e9040dc9e1b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 823, 3789.0, 1946.2),
('e4b757f9-204c-53f5-a40a-482a8f1d0542', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 824, 3791.7, 1947.5),
('43819037-5e95-580f-9722-5a7b486d0128', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 825, 3794.4, 1948.8),
('0df50aef-2c7a-5a50-a973-0b24b3f74056', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 826, 3797.1, 1950.1),
('dd4051a6-7e74-543a-a534-a9767e9decd7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 827, 3799.8, 1951.4),
('790f018e-98fe-5e80-aabe-abf2bffcff93', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 828, 3802.5, 1952.8),
('a8c10b36-8dc7-51fe-b54f-10e21c8cf5be', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 829, 3805.2, 1954.1),
('ca0b2da4-5a73-5fc1-8bf4-a03f79364103', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 830, 3807.9, 1955.4),
('9cad8640-4607-5e16-9dc9-5393be9f11dd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 831, 3810.6, 1956.7),
('03b53a85-7287-5e88-8903-e18055ca5a4f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 832, 3813.3, 1958.0),
('32c45c55-0aef-5df7-9c4d-2463e8f111d1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 833, 3816.0, 1959.3),
('66c42a45-1d71-58e7-a433-294cb0e4cb9f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 834, 3818.7, 1960.5),
('9f2e1581-0095-5389-95a8-3da6bd397f76', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 835, 3821.4, 1961.8),
('ec19874d-5206-56e4-96c8-dac3760b14d2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 836, 3824.1, 1963.1),
('ccb719b7-17be-51a0-9538-7b4b7b8a30ab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 837, 3826.8, 1964.4),
('ad037c94-f2d8-57ff-aa96-a36b40914009', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 838, 3829.5, 1965.7),
('991c38a3-50d3-5f6d-862f-10fe8076f643', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 839, 3832.2, 1967.0),
('fa27a562-838c-5323-b51e-ccb1c8fc8c3f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 840, 3834.9, 1968.3),
('d705ac4c-a2d2-5910-bfb0-c974934ef8bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 841, 3837.6, 1969.6),
('af890d45-548a-5c94-8923-79993c8727e3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 842, 3840.4, 1970.9),
('2911fd75-0977-52bb-8ab3-66dc04c24ee4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 843, 3843.1, 1972.1),
('f21e2045-2c18-5698-ac0e-d91195af5f44', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 844, 3845.8, 1973.4),
('47cb4854-cc24-543e-acf8-ad3bf0018f94', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 845, 3848.5, 1974.7),
('78c8df14-fc84-5047-94af-dd246e50c1e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 846, 3851.2, 1976.0),
('a5ebc954-d665-5d00-8ae8-f415fc42a016', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 847, 3853.9, 1977.3),
('fa9c3c08-79c0-5b9c-82be-dfef7e560744', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 848, 3856.6, 1978.6),
('0b58a003-b2c6-560a-97c7-cf294ead0a2c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 849, 3859.3, 1979.9),
('70eaf777-b8a3-543a-bec5-4682e06197f6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 850, 3862.0, 1981.2),
('8b16c471-2e62-5438-8613-ee6d403bb600', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 851, 3864.7, 1982.5),
('1347495b-e333-556b-a1f5-f60913ac71d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 852, 3867.4, 1983.7),
('d633b940-1550-5bef-8a3f-d044e49358bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 853, 3870.2, 1985.0),
('5cd836b2-db5b-5c4e-9bee-a09310a9c7b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 854, 3872.9, 1986.3),
('3b921d0b-ce29-510e-a911-2451bbf019d0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 855, 3875.6, 1987.6),
('d01124ba-92cf-5aca-911c-b39a1562c431', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 856, 3878.3, 1988.9),
('663ae33f-4848-567e-82b2-06b36a8b9e6a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 857, 3881.0, 1990.2),
('7705c87d-d391-58f1-b069-133cdc8a748a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 858, 3883.7, 1991.5),
('7242bd77-a83d-590e-ae6f-b79a431e91be', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 859, 3886.4, 1992.8),
('7c68f018-c8a7-53e4-9e30-1421b9ed4664', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 860, 3889.1, 1994.1),
('a66c62f7-e2ee-5ec5-a046-2574474eb8d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 861, 3891.8, 1995.5),
('8bd89510-4aed-5bae-9229-312054144c73', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 862, 3894.5, 1996.8),
('9d2b5019-b7e9-557d-987e-27db3c37822a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 863, 3897.2, 1998.1),
('dea5cc7f-a096-5cf9-9b9d-345c47c1399e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 864, 3899.9, 1999.4),
('a4bd4df3-e43b-5383-b626-8c5ea1cedb43', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 865, 3902.6, 2000.7),
('ad1c31cd-7a40-5f78-8050-7ee12aa0c911', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 866, 3905.3, 2002.0),
('50eb1b39-fe96-58e7-996d-e1990922f6fe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 867, 3907.9, 2003.4),
('0bc4e755-19fd-58df-bf89-e601f8a28cfd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 868, 3910.6, 2004.7),
('64bd3f5c-029c-5037-8458-3b67809d1290', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 869, 3913.3, 2006.0),
('99b44d8d-af68-5bde-85a3-ef712c3b1b8e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 870, 3916.0, 2007.4),
('c2d842e6-0ec8-530d-aeb4-0804afa3f65a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 871, 3918.7, 2008.7),
('1dbb32e5-8f02-55f2-82db-10b39c242a18', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 872, 3921.4, 2010.0),
('1e690c67-d838-5cef-90cc-f76807d0d839', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 873, 3924.1, 2011.4),
('7b29d4e1-d2d3-5147-a216-f75506b2cb79', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 874, 3926.7, 2012.7),
('e0584784-d662-5c92-906b-695b0b2261d8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 875, 3929.4, 2014.1),
('3401678f-4c9f-5a9d-a6f0-884c895776a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 876, 3932.1, 2015.5),
('1cd2bfb5-fa0a-5909-88a5-9a7b7d41539b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 877, 3934.8, 2016.8),
('cba38550-266b-54ed-8d07-8073421d19d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 878, 3937.4, 2018.2),
('28af511a-cc30-5f6a-acdb-20a4e75554eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 879, 3940.1, 2019.5),
('1827fc37-7a7e-52c7-bb96-d39c38809bb6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 880, 3942.8, 2020.9),
('cd7ce437-971e-5ac3-a3b0-edb973defcd3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 881, 3945.4, 2022.3),
('ca07015a-4141-582d-a045-aecf45721661', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 882, 3948.1, 2023.7),
('864037f8-aa6a-5618-9360-3d7f507900df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 883, 3950.8, 2025.1),
('a845763e-84cb-53aa-9d03-37cfb82b7049', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 884, 3953.4, 2026.5),
('ec7bd438-fa01-505d-87eb-453e9b9350c8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 885, 3956.1, 2027.9),
('0721e301-f19a-5426-b4f0-f9d615b14cd0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 886, 3958.7, 2029.3),
('a2759b3e-e9d6-5569-8148-e2684bddc6eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 887, 3961.4, 2030.7),
('540b4a8e-3162-5540-81a1-5e11dfcd4fd2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 888, 3964.0, 2032.1),
('c1e9709a-2039-550a-bca3-5a41f442f4f2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 889, 3966.7, 2033.5),
('3f5d2e72-9150-54cd-bf0c-c58759a7f668', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 890, 3969.3, 2034.9),
('08a7043b-818f-52d0-8c04-00acb4b104e7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 891, 3971.9, 2036.3),
('4b56a6bb-4f8b-54b0-8c9e-32853b3bbf91', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 892, 3974.6, 2037.8),
('3e3dc9a8-0471-5954-8a7e-40c950178094', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 893, 3977.2, 2039.2),
('2c986c3d-0c8e-5bf7-b21f-17f39deb5f1d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 894, 3979.9, 2040.6),
('276222f9-adc3-55d6-87c5-babc6e5da367', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 895, 3982.5, 2042.1),
('a2108638-466d-58e7-a9e5-61155f4b7f02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 896, 3985.1, 2043.5),
('58b41aed-8f49-59ba-a07b-fde517d1d518', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 897, 3987.8, 2044.9),
('7815f964-b554-574d-9131-b3be0ccf2d23', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 898, 3990.4, 2046.4),
('23cb2fc4-a9a8-5465-98b1-2715aa1a6119', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 899, 3993.0, 2047.8),
('145e7ed9-b956-5c7b-9036-8cc7af303051', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 900, 3995.6, 2049.3),
('07f6b430-a928-5d0f-969f-094b0481fe6b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 901, 3998.3, 2050.7),
('dd836d80-7e85-5530-9d0e-dc43d0e49685', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 902, 4000.9, 2052.2),
('ce606d07-9166-5817-a213-72df960945e6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 903, 4003.5, 2053.6),
('1d8b3b51-57f3-5030-9e9a-a8922bbe5ebd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 904, 4006.1, 2055.1),
('5514454e-61fc-5a56-8f86-a8cbe117ce0b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 905, 4008.8, 2056.6),
('65a20d8d-dedd-5ff4-9cd7-8a389f4c6a36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 906, 4011.4, 2058.0),
('69d2fb3d-56da-5380-9c3c-82381c232a24', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 907, 4014.0, 2059.5),
('06cf25dc-2255-5958-92d6-cc8ac0c4116c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 908, 4016.6, 2061.0),
('4236636c-7861-5a8f-9b82-047a84a809f8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 909, 4019.2, 2062.4),
('7b9dcb2d-7614-5f2d-8727-077545289e49', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 910, 4021.8, 2063.9),
('7da16be7-e97c-576f-b39f-cbd924c256e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 911, 4024.4, 2065.4),
('e6b8ecb1-3076-5993-9596-185ef0bd7905', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 912, 4027.1, 2066.9),
('a4678a13-def4-5edf-8770-ad4c7e69f51c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 913, 4029.7, 2068.3),
('b099c9bd-e891-5d54-8fab-1b5ab9655a8a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 914, 4032.3, 2069.8),
('1feea604-dc33-5b64-ba37-fbd648b047d3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 915, 4034.9, 2071.3),
('35dd75b3-5668-57f2-9021-0a89019922fc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 916, 4037.5, 2072.8),
('033f278c-ba67-5b40-a6e1-a85e548a1095', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 917, 4040.1, 2074.3),
('f1a3ef47-7372-555b-b1ce-2e477cfd5b65', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 918, 4042.7, 2075.8),
('1cb335b1-e7d5-556e-b808-baa4a64b49e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 919, 4045.3, 2077.2),
('4d384c05-bf76-54a6-a527-6b696a559fec', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 920, 4047.9, 2078.7),
('40a03975-9244-5afa-87a5-de1d99d4eda6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 921, 4050.5, 2080.2),
('fa59e17c-c53b-536f-b52e-322ebcbb6ce5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 922, 4053.1, 2081.7),
('6bb6d7d4-753f-5096-9df3-285ee115fc51', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 923, 4055.7, 2083.2),
('0c845542-2760-5091-818b-4240fc8fa358', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 924, 4058.3, 2084.7),
('03269a7f-8640-50b6-82d2-6afcf225e474', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 925, 4060.9, 2086.2),
('c5e95c75-8cef-518b-8f42-a10520cbce91', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 926, 4063.5, 2087.7),
('3cabb1ba-0c97-5d2a-9b8e-5a5d1b4cf912', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 927, 4066.1, 2089.2),
('1e940262-095a-599a-a25c-b569e33e35b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 928, 4068.7, 2090.7),
('4458cd3f-dceb-5a2c-98bf-dacc9e6d7f33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 929, 4071.3, 2092.2),
('70e3afe6-be30-59f4-b08c-351e708ba8f7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 930, 4073.9, 2093.7),
('58e4d69e-9afa-5cf1-871d-75fc87cc2d9a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 931, 4076.5, 2095.2),
('67921537-d17f-5bbe-9b6b-482cbfc1648a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 932, 4079.1, 2096.7),
('43ea7da4-9381-5159-ae4d-4e4fab81db23', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 933, 4081.7, 2098.2),
('186480d7-cd84-5992-aa5f-7d7d14822d3b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 934, 4084.3, 2099.7),
('6232b746-76bd-533d-9622-6fa9295c230f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 935, 4086.9, 2101.2),
('57a598a8-09a8-5914-91d8-4a1b167f7b74', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 936, 4089.5, 2102.7),
('b5941fd3-c60e-59ab-a3a7-14ef692fca67', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 937, 4092.1, 2104.2),
('7a6c2cf8-3e27-5992-b8d0-3687389a1a02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 938, 4094.7, 2105.7),
('e0fbb02d-25cf-5285-ad94-2d57f8273aa0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 939, 4097.3, 2107.2),
('555a06eb-8401-5867-aa58-459c8d217a12', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 940, 4099.9, 2108.7),
('4e410cce-61f8-5bfd-852c-e41e9cffb556', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 941, 4102.5, 2110.2),
('07b28594-27a1-523c-951e-ec106bd900bc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 942, 4105.1, 2111.7),
('6d0714b8-6103-56a3-82e2-54e06904cda8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 943, 4107.7, 2113.2),
('4350116a-264d-5334-8d68-98c5687bfb55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 944, 4110.3, 2114.7),
('281cb87b-f06e-5e08-8528-2931fbcc292e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 945, 4112.9, 2116.2),
('4edb7ae8-f195-568c-8576-a7e8e2992255', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 946, 4115.5, 2117.7),
('9b92106e-aa20-598e-a9ab-ea037cb2191f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 947, 4118.1, 2119.1),
('5473d94e-1868-52f3-92cb-46fbe3938d69', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 948, 4120.7, 2120.6),
('8a3e328d-ba1f-542e-81e6-b1ee759df896', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 949, 4123.3, 2122.1),
('881a2408-d78e-5a23-af09-9a84fcc4bd02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 950, 4125.9, 2123.6),
('618ac189-2fac-580e-9179-58dd8043fc4c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 951, 4128.5, 2125.1),
('4a0d66d2-90f9-5dbb-8c32-469128d9e2bc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 952, 4131.1, 2126.6),
('9e5cd229-dab9-5095-aeac-03bc4e803922', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 953, 4133.7, 2128.1),
('c6deed90-99d2-5fcd-9740-3667454e8920', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 954, 4136.3, 2129.6),
('2d52f6ae-39d6-522b-add9-3de414c4f98c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 955, 4138.9, 2131.1),
('7f475aa8-2755-501c-af4d-2bd5bca28917', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 956, 4141.5, 2132.6),
('0fd80b8c-7df8-5981-ba08-8d82219c909a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 957, 4144.1, 2134.1),
('09e619ca-88fe-50af-bdc8-979ea25a0d05', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 958, 4146.7, 2135.6),
('79fd8c5c-5187-5e6d-a33d-d6b78a49b5df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 959, 4149.3, 2137.1),
('b7a1c542-8a49-574f-9bb3-d2767dde8b44', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 960, 4151.9, 2138.6),
('7db27277-64ec-5840-9fbd-49813eafedfb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 961, 4154.5, 2140.0),
('77841369-49eb-5952-88ed-c8cc9932c70c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 962, 4157.2, 2141.5),
('849942e9-d440-50bf-bd90-b2be8ae59a92', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 963, 4159.8, 2143.0),
('b81d7ab6-8fcb-58f4-98f7-3f37e8450037', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 964, 4162.4, 2144.5),
('f0e54137-6a22-5897-8bc1-6aaaf84802e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 965, 4165.0, 2146.0),
('e6756b4a-fe34-503f-bac3-13f0de8a0cbc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 966, 4167.6, 2147.4),
('08e36157-314b-5e4f-9b52-f3bb238dbfda', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 967, 4170.2, 2148.9),
('4e35444d-a0b9-552b-a2a1-4a023e69af11', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 968, 4172.8, 2150.4),
('8a85eef2-a9e3-5952-9a32-eec74e68b7da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 969, 4175.4, 2151.9),
('765c26fa-a5c7-5263-9729-6e346bcc0605', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 970, 4178.0, 2153.4),
('a6153ae9-607c-53c2-8311-74d59d014d9e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 971, 4180.7, 2154.8),
('75d5fa50-ec59-56d0-aea2-751c9fcef2ff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 972, 4183.3, 2156.3),
('9164865c-7d55-5e35-bb4f-981731c00835', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 973, 4185.9, 2157.8),
('bc541139-1fe5-5b25-b25b-ac37a50748b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 974, 4188.5, 2159.2),
('8a085755-e6a3-5ca3-bf3e-bbe9b727dfa7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 975, 4191.1, 2160.7),
('cd6f5c6a-3d62-5f33-a1b0-a73f43fc1ae6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 976, 4193.7, 2162.2),
('93778e89-8921-5838-990a-c557f3d3b67b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 977, 4196.4, 2163.6),
('5919d07c-6467-5153-a20d-2c3449552d6b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 978, 4199.0, 2165.1),
('7ca175b5-3c08-5fd7-8e2c-4a4102f90106', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 979, 4201.6, 2166.5),
('5e41caf3-1d5f-51cb-9ab1-100fc502a0ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 980, 4204.2, 2168.0),
('31d02e47-2639-5ca2-905f-9428559532dd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 981, 4206.8, 2169.5),
('f7a1d1de-26d0-5c5b-ba49-305c34cbec5f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 982, 4209.5, 2170.9),
('9a38debd-2a83-5d05-a656-b901d204bad3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 983, 4212.1, 2172.4),
('4a639d85-4b12-5530-81e1-c9997e2b5b41', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 984, 4214.7, 2173.8),
('e28b35bd-3b25-5a45-8c85-8dffe1ab41bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 985, 4217.3, 2175.3),
('801dd65a-7e3e-52e9-ac29-fc964702f4a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 986, 4220.0, 2176.7),
('fb7503f7-43f2-5301-89bd-80aaebf048bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 987, 4222.6, 2178.1),
('acfacdf3-6815-57e6-baa3-32dbea7e17bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 988, 4225.2, 2179.6),
('3e1782c3-f320-50de-8516-2b53ef056808', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 989, 4227.9, 2181.0),
('ab846fe6-b629-5ffb-99a4-04902f9c119e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 990, 4230.5, 2182.5),
('fac2d9a4-3337-5a4f-bc4b-9b34c9f426c2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 991, 4233.1, 2183.9),
('b4d99a3b-c32a-52c4-8f92-280336d1040c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 992, 4235.8, 2185.3),
('5d6c92b2-7d08-5819-ae11-8186e254ee20', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 993, 4238.4, 2186.8),
('eac6c299-27e7-5ebd-b489-a42677d8ae10', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 994, 4241.0, 2188.2),
('b1b15441-7e9e-5d56-a0c4-cc9fca17f776', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 995, 4243.7, 2189.6),
('58b5cf10-8001-5c30-bfec-83bc02577be6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 996, 4246.3, 2191.0),
('d6104a35-c8a9-52e8-9ce5-faf350d0e2cf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 997, 4249.0, 2192.5),
('3e8163a6-d2f5-5c02-8449-b030394e22d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 998, 4251.6, 2193.9),
('ece6d6d3-c92f-5473-a5e5-d6908c30f79b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 999, 4254.3, 2195.3),
('b4b488a4-6aac-584d-81bb-9a8cbdf88746', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1000, 4256.9, 2196.7),
('cda8f266-a470-5723-be5e-37bd9a154400', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1001, 4259.5, 2198.1),
('84ee8e30-1adc-586b-aaed-992601d1416c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1002, 4262.2, 2199.6),
('cc9d71de-8275-5bf7-88e7-c2f6aa5f439c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1003, 4264.8, 2201.0),
('1779490c-5192-5b99-9ec2-5aeaf3e4e9d2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1004, 4267.5, 2202.4),
('ba23d726-08de-5e6f-8bf2-4679ef6d11e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1005, 4270.1, 2203.8),
('11ed6b11-14ec-512d-9780-36e89dbc6637', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1006, 4272.8, 2205.2),
('542a400f-0c6b-5310-9de5-bea0d79f8ee0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1007, 4275.4, 2206.6),
('ad95fd92-efe8-5666-a4cf-93f286f9cd6a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1008, 4278.1, 2208.1),
('8ac060d5-adef-5537-bfae-0d1059f8e6f7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1009, 4280.7, 2209.5),
('2aeab92c-66f4-53e1-922e-018bc7c442ab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1010, 4283.3, 2210.9),
('96d38e71-7631-5925-911c-b2abba69a2c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1011, 4286.0, 2212.3),
('0ab75c16-325e-5956-a36a-9d5aa2a66462', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1012, 4288.6, 2213.7),
('6fc6881f-bcbf-5097-a02f-298b0e590e39', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1013, 4291.3, 2215.1),
('4b33a201-cb82-5719-b393-6249c39c7d20', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1014, 4293.9, 2216.5),
('95c5f5b9-1453-550d-861e-723bb5d61f55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1015, 4296.6, 2217.9),
('c17cf673-4cd2-53ed-9610-04972ec16c3a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1016, 4299.2, 2219.3),
('f5314244-88c2-5ed9-b6bc-a0a70ee8029a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1017, 4301.9, 2220.7),
('8b8fa616-87be-57a3-9fab-ffb19eb9e0b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1018, 4304.5, 2222.1),
('3fe596d2-b6fd-54b9-af3b-2a18767b02ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1019, 4307.2, 2223.5),
('ba13bad1-f753-54da-8399-fa653cf32e17', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1020, 4309.8, 2224.9),
('45c4e864-dd72-5f75-b138-a7db29c7b11a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1021, 4312.5, 2226.3),
('37041200-396b-5885-aa5b-aeaad4d02544', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1022, 4315.2, 2227.7),
('d5e0b127-3306-5b41-885b-b91d7e35fbd5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1023, 4317.8, 2229.1),
('f3ea35f9-7ee0-5477-a989-9bb3acc352ab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1024, 4320.5, 2230.5),
('734058a9-2012-5c53-a6b7-3c2531aaa6cf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1025, 4323.1, 2231.9),
('f7d71f1d-0360-5554-b200-b8427e810133', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1026, 4325.8, 2233.3),
('9c3c53db-effc-57e8-a831-de5022ec6fb1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1027, 4328.4, 2234.7),
('a0c6bfd2-3bd0-5a33-afd6-7e038394a6a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1028, 4331.1, 2236.1),
('3f0d20c4-a6a1-5de3-9319-de8d0b320f4d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1029, 4333.7, 2237.5),
('34261da0-c745-5b99-816b-fd21f05dca5d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1030, 4336.4, 2238.9),
('1ec2351a-2c38-53ec-87b7-8b39c83b20f2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1031, 4339.0, 2240.3),
('28360a9a-21e0-5a6c-82b7-f6a998bbae7d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1032, 4341.7, 2241.7),
('cf64a34d-fb47-501d-8fde-20ef4935adc2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1033, 4344.3, 2243.1),
('0c56a93f-431f-5714-8049-cccd8dc8dfcd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1034, 4347.0, 2244.5),
('1b140859-451f-5217-bc9d-9c5ef697dbda', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1035, 4349.7, 2245.9),
('abe3f2e8-ff65-5dc0-b119-1209cfbf3b60', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1036, 4352.3, 2247.3),
('b7efeb92-6ab6-5b70-bae1-130702372135', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1037, 4355.0, 2248.7),
('834487e1-b410-5c3d-a8cd-e070087be80c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1038, 4357.6, 2250.1),
('5ab8c96d-c716-5674-8dfa-e5d0f89276c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1039, 4360.3, 2251.5),
('e4822187-a86c-535f-80ae-b23af92b0a66', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1040, 4362.9, 2252.9),
('a7b9d05e-21c7-5740-a23a-b373b3a84de4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1041, 4365.6, 2254.3),
('e5e4eafa-8f7d-5fcd-8ddc-851ea3e876c3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1042, 4368.3, 2255.7),
('72c3699b-7eed-51ef-a209-20596a01917b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1043, 4370.9, 2257.1),
('ef0d007b-d8da-5e72-b0d0-ebdb0a5f7c71', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1044, 4373.6, 2258.5),
('8fd52330-cb56-536a-bd70-e4d6682d8f52', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1045, 4376.2, 2259.9),
('ee5f70c5-2084-5c9a-9411-aad874d5968d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1046, 4378.9, 2261.3),
('1ee62ef7-9924-5b84-b768-d6d4b1adec56', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1047, 4381.5, 2262.6),
('791ebe79-b92b-52d7-935f-0f8eb7ac97b1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1048, 4384.2, 2264.0),
('f06a1342-5211-5bc4-9a2c-d7e1ff91ffaf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1049, 4386.9, 2265.4),
('1d0b87fd-a0c6-5c0f-afac-ee78527cc365', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1050, 4389.5, 2266.8),
('3c1a5261-8e1b-5669-9654-31b9363318de', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1051, 4392.2, 2268.2),
('1573ab56-957a-549a-97b4-323ad106efa7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1052, 4394.8, 2269.6),
('1cfc16ae-1722-52a9-853b-1c609691f8d3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1053, 4397.5, 2271.0),
('a9bf26de-2637-5809-9610-022b7e0e5c29', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1054, 4400.1, 2272.4),
('a92acae7-f3bd-56ff-8f30-1a02747713f5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1055, 4402.8, 2273.8),
('4140dc7d-1021-51ee-a221-534495286f3a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1056, 4405.5, 2275.2),
('444118d2-8c3e-53fc-8b8c-f313af7a9e89', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1057, 4408.1, 2276.5),
('c7d47293-8187-566b-a575-07b87d6d0130', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1058, 4410.8, 2277.9),
('e15fdbae-f0e1-5e91-9fa7-d042539ba8c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1059, 4413.4, 2279.3),
('7232b814-59e2-526f-afae-32a7915a65b0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1060, 4416.1, 2280.7),
('de6d9590-01ad-5a43-8685-3801011ca447', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1061, 4418.8, 2282.1),
('2712900c-75c8-5b06-8eb3-1b3d44eb5d42', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1062, 4421.4, 2283.5),
('19fe1f7a-2078-51c3-a6c7-25ce3fac9607', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1063, 4424.1, 2284.9),
('d24da6a6-df3a-518b-a18a-054e53831dce', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1064, 4426.7, 2286.3),
('9d9f4bd4-fe24-58f3-af71-fe13cc2bfce4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1065, 4429.4, 2287.6),
('dae517fa-82e8-5356-9f19-4e483891cb95', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1066, 4432.1, 2289.0),
('b70e6c1b-ecee-5153-ae22-6f9e753db1d8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1067, 4434.7, 2290.4),
('fdcc7789-2584-5d14-8166-38a4e3bfdeaa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1068, 4437.4, 2291.8),
('f5dfac88-6752-5cfd-87e7-6624bd658cfc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1069, 4440.0, 2293.2),
('743b38ad-042a-54c5-9ca7-12b861e4f5ee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1070, 4442.7, 2294.6),
('57a33058-9439-54bc-8d69-fab873e2d21d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1071, 4445.4, 2296.0),
('8c54e62a-d537-5d3d-b28a-abe812d1745e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1072, 4448.0, 2297.3),
('59f8f937-8316-5342-a706-a211760847ac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1073, 4450.7, 2298.7),
('ba21a38e-7703-5859-ba3a-441557474413', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1074, 4453.3, 2300.1),
('8c6cbf2e-c2c3-5058-a4c4-52dae0b33d25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1075, 4456.0, 2301.5),
('b32de5c9-a2c4-5f9d-848d-dfa50c09eb7a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1076, 4458.7, 2302.9),
('0064f044-bec4-520b-9265-b893cc8c58a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1077, 4461.3, 2304.3),
('d65c8957-ca51-5f84-838c-ebf8ed756131', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1078, 4464.0, 2305.7),
('64b16d58-258a-5b8c-a9a3-2384dbf40d1e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1079, 4466.7, 2307.0),
('055f0d58-92c8-538c-8102-11f328c8b026', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1080, 4469.3, 2308.4),
('7eed4919-4303-59ea-bf72-02a726c4f125', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1081, 4472.0, 2309.8),
('4a320b96-1e5e-508b-a329-e39b0c5f4385', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1082, 4474.6, 2311.2),
('e3e50eed-2b89-5050-8cdc-969c1bb39091', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1083, 4477.3, 2312.6),
('c08339cf-6ed7-587a-8e15-e31c3cf27dc4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1084, 4480.0, 2314.0),
('1bc5765a-581f-5dd2-8096-27ac65d98b0c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1085, 4482.6, 2315.3),
('88bb3096-2c9c-54fa-9d14-92cf6c4bdac2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1086, 4485.3, 2316.7),
('4be7aee4-4d28-516b-84a0-f67bad0b2b9b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1087, 4487.9, 2318.1),
('e32c10b9-28a3-53b8-8a2d-365e5c718c85', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1088, 4490.6, 2319.5),
('8f6c2c0e-3cb4-57b9-9b6b-756ee1a57071', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1089, 4493.3, 2320.9),
('46bdd131-5fd7-5042-8a9f-db09ba750e25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1090, 4495.9, 2322.3),
('8385c57a-d682-5f40-a34a-b542edccc018', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1091, 4498.6, 2323.7),
('0d817c00-c966-5cdd-96f6-4169b2b6267e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1092, 4501.3, 2325.0),
('d88089a3-3709-586d-a1b0-c0210108c2aa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1093, 4503.9, 2326.4),
('c949f0d0-4d3d-52b8-b919-64f6c7c8d00e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1094, 4506.6, 2327.8),
('5e3ae33b-890f-5a14-a1bb-ac5a6e005d50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1095, 4509.2, 2329.2),
('92674f76-070b-5a4f-9d4e-ab934077d6c4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1096, 4511.9, 2330.6),
('7b8ef8c7-e4ce-5183-8731-1620e1674671', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1097, 4514.6, 2332.0),
('637580cc-28b5-54cf-af7f-d612cd3cf512', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1098, 4517.2, 2333.3),
('d6e12145-1497-590f-82cc-a26d5f5c0f2b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1099, 4519.9, 2334.7),
('4e72d23f-7c56-5051-9abe-70a1f0af48cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1100, 4522.5, 2336.1),
('f07b2d4f-257e-5da7-9469-a5d72d970457', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1101, 4525.2, 2337.5),
('1f51102d-acc0-5d97-8a8c-0c7bfe680ab9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1102, 4527.9, 2338.9),
('d945df98-068c-53d2-b072-e2cbc3807e95', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1103, 4530.5, 2340.3),
('0ec8e8cd-0383-5289-80a6-bebe51308934', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1104, 4533.2, 2341.6),
('30b8d284-faeb-59e5-8506-9bebb8432274', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1105, 4535.9, 2343.0),
('9fb0fd6f-1ffd-52ad-9c46-80e79998d880', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1106, 4538.5, 2344.4),
('8b091081-bc4d-5003-9d3d-605b278fa31b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1107, 4541.2, 2345.8),
('91a0f65a-7815-5ac0-a02c-8dad0021622b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1108, 4543.8, 2347.2),
('da385a41-09be-56f6-aeb8-00540dcc5f8c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1109, 4546.5, 2348.6),
('14cea1d5-a095-5638-84db-a02c3fd03ee0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1110, 4549.2, 2349.9),
('e829a107-0317-528b-b971-fe49e9551c83', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1111, 4551.8, 2351.3),
('e439df64-9c70-5953-b0f4-dc6dbcff580c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1112, 4554.5, 2352.7),
('8cfc471a-e7f8-5a9a-8c83-8aaea568450f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1113, 4557.1, 2354.1),
('ffcfdddf-3e3a-5a67-9b8b-582e68758968', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1114, 4559.8, 2355.5),
('4a1987db-87c6-5419-9b79-2bfac6046aba', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1115, 4562.5, 2356.9),
('2cb17529-7880-566e-aa6f-3b30245b254f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1116, 4565.1, 2358.3),
('2b8f95b1-0931-51a5-9567-53f8686c259b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1117, 4567.8, 2359.7),
('d5ee6360-d827-5bb1-9721-0e9d611741ba', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1118, 4570.4, 2361.0),
('700e2d97-9a86-5601-b876-6a1ec26e3965', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1119, 4573.1, 2362.4),
('b2b25ce8-f169-51d6-9391-481644f4cded', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1120, 4575.8, 2363.8),
('3311fd18-4007-53f9-95ee-036c12cb2858', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 0, 1121, 4578.0, 2365.0);

INSERT INTO level_path_point (
    id, level_info_id, path_index, point_index,
    map_position_x, map_position_y
) VALUES
('63151140-adc5-5329-be91-1781ac42a7f7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 0, 4406.0, 658.0),
('5260478a-9878-5093-a738-995bee1a1b23', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 1, 4404.7, 660.7),
('526a7a8e-5202-5ae3-a4b4-ecbc698495b7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 2, 4403.3, 663.4),
('278c232f-cfef-5f53-8952-60ec1ded8b3b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 3, 4402.0, 666.1),
('fa22a9d2-79cc-5e15-b605-19cf77678c93', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 4, 4400.7, 668.8),
('38bba96e-e5a3-5fd6-9ea4-1f6a7a6fc16c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 5, 4399.5, 671.5),
('8b23dd84-e056-5c50-a57b-3c627cba3594', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 6, 4398.2, 674.2),
('aaffb7d2-d950-540c-a7a1-36bfcb508117', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 7, 4396.9, 676.9),
('e345763f-85d7-5156-b3ff-88a950317330', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 8, 4395.6, 679.7),
('d7f9507d-a02a-546e-86a4-6fa7b04053ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 9, 4394.4, 682.4),
('58e101cd-50b7-55df-b8f4-802320ecf56c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 10, 4393.1, 685.1),
('2c8d0fde-1306-56e9-add9-0cab7d2d2584', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 11, 4391.8, 687.8),
('14d831fb-7926-5e2b-aca6-dec14f8a0684', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 12, 4390.6, 690.5),
('e41cf7ca-838d-5d18-a46d-d43bb0bab9b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 13, 4389.3, 693.2),
('28130b7d-6533-50e0-bbda-4dd2df55484c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 14, 4388.0, 695.9),
('771ecf63-74f5-5e6b-9725-752b6ab0da59', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 15, 4386.7, 698.6),
('04b7c626-0bfc-5904-9a3f-ff447ff29394', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 16, 4385.4, 701.4),
('ad92d57a-617a-553f-a92b-6db850da222c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 17, 4384.1, 704.1),
('772cacdf-b5d8-5612-896a-d20d0af9c0df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 18, 4382.8, 706.8),
('f2d4a6d7-511a-53bb-b10f-b09f8e52fc8b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 19, 4381.5, 709.5),
('c304b69b-1153-5cd4-aa88-1a4b1e0e368e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 20, 4380.2, 712.2),
('44e5c9f2-fc1c-5acf-913f-5114a61fb60e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 21, 4378.9, 714.8),
('64b5ad9b-5395-532a-b28b-f300aa49991e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 22, 4377.5, 717.5),
('e582ec5c-42bc-5622-a28f-5b1bfcf0b6a3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 23, 4376.2, 720.2),
('084a7a1d-37d0-5b50-b8c9-0dc9cb73fa67', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 24, 4374.8, 722.9),
('eb21c66f-5539-55db-9555-edac2a474a4d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 25, 4373.5, 725.6),
('55214242-f4d1-50a6-a166-f09b8702994f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 26, 4372.1, 728.3),
('7a325e23-c789-58ae-99ef-9d87acc8215e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 27, 4370.7, 730.9),
('19f87624-f892-5916-ae16-8d20a5aa699e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 28, 4369.4, 733.6),
('bcb427eb-bf06-5fa1-89b3-6118530e6e16', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 29, 4368.0, 736.2),
('48ba3681-38ae-565b-9200-c98612079cfd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 30, 4366.6, 738.9),
('dda74535-f5da-5ee6-836e-34d19294d270', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 31, 4365.1, 741.5),
('e0c09db0-0cbf-549a-9a5f-e850c3b198fa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 32, 4363.7, 744.2),
('8b9c0721-f34b-5dda-89a9-057aacc2e75a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 33, 4362.3, 746.8),
('97b0a5f2-a050-58c8-98a5-cfe88464af8e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 34, 4360.8, 749.4),
('3bc415d4-3cce-5d41-87e9-39f13813ebfd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 35, 4359.3, 752.0),
('2c2606fd-bf63-5eae-93ac-c0bac69aaff7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 36, 4357.9, 754.6),
('dd105894-3b4b-5f6e-b69d-8cdd0cd59660', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 37, 4356.4, 757.2),
('96ae00f1-11b7-56c0-bd55-275c6c7a3530', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 38, 4354.8, 759.8),
('249869d4-1c25-531d-9852-2fc03eeba629', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 39, 4353.3, 762.4),
('07061e28-f066-518d-b8e0-5a0c54fd7713', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 40, 4351.7, 765.0),
('7cd43e7d-58dd-5ae3-a5b4-0fba0d8ad7fc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 41, 4350.2, 767.5),
('63f3d8f4-2240-5f3a-9b9e-fe897e374316', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 42, 4348.6, 770.1),
('1e3b63a6-fd48-562f-8f71-7b2cf719d14a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 43, 4347.0, 772.6),
('2cdaff17-03a7-5f53-b146-4bc240c0ef5a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 44, 4345.3, 775.1),
('02e2c381-4802-5e8d-99fa-12eac26ce8ab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 45, 4343.7, 777.6),
('5775b65c-f51e-5601-bf0d-85f83f75c5ff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 46, 4342.0, 780.1),
('e3ba2081-f634-5dd7-8638-58207ec9f7dd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 47, 4340.2, 782.5),
('caa57275-ef11-5963-864d-bef386526e84', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 48, 4338.5, 785.0),
('b10a76ae-dadb-5416-a0a8-6713ffc43905', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 49, 4336.8, 787.4),
('f1327b24-54e9-52e3-9a8d-5e59792af742', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 50, 4335.0, 789.8),
('3f363356-f9f7-5f84-80fb-73012210158d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 51, 4333.2, 792.3),
('ad9a9f63-17b3-5915-80ab-a7f6106c4f36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 52, 4331.4, 794.7),
('a7601f74-7f9e-52ad-a016-333c71ef04cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 53, 4329.6, 797.0),
('dcc56fa6-a18f-5aec-b520-8bb61167fa5e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 54, 4327.8, 799.4),
('e7db53bc-8f5e-59ff-a813-9f6fbc1a06bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 55, 4325.9, 801.8),
('3b4ce598-b129-58b2-9744-0abc2acab8bb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 56, 4324.1, 804.2),
('94f8cf59-e394-5f8a-8f7e-79d6507af86d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 57, 4322.2, 806.5),
('fa503e0e-8784-5992-bda3-bf99730ccdca', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 58, 4320.4, 808.9),
('315f30ea-6efb-5894-896f-2992238d9af2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 59, 4318.5, 811.2),
('6f8de612-edea-5118-baf2-a8469b5d8c40', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 60, 4316.6, 813.6),
('35565e14-7c8a-51c3-a5d7-54aa378e94b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 61, 4314.8, 815.9),
('9e945e5f-7173-506f-a214-122ddec09a89', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 62, 4312.9, 818.2),
('edf984a8-7c9c-5979-abfd-dbc49a1a6620', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 63, 4311.0, 820.6),
('7b943942-0e71-57af-8ab5-185f056b22c5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 64, 4309.1, 822.9),
('612e4db5-af48-59a1-ad05-c3ed89e3fc11', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 65, 4307.2, 825.2),
('47938baa-7c49-512f-9ea5-be66f1bb1d50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 66, 4305.3, 827.6),
('c14bfd1d-5b68-50b6-a256-07f2bf2a2d38', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 67, 4303.4, 829.9),
('bac97067-6cae-56d5-a114-eb80a157e2fa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 68, 4301.5, 832.2),
('3da50a2f-23bc-5ab3-85f4-f679944874c2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 69, 4299.7, 834.6),
('791c1083-8429-5057-996f-c3897acb22da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 70, 4297.8, 836.9),
('a4b69ca2-7e80-511a-9f76-07d06e7ffc8c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 71, 4295.9, 839.2),
('af28d4e7-280c-55b9-a43e-a733d6bf8004', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 72, 4294.0, 841.6),
('e2ebe963-dbcd-5590-ba09-77c9a71798af', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 73, 4292.1, 843.9),
('8c98a157-a14f-594c-b271-cc0ef86c92e1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 74, 4290.3, 846.2),
('78dce91e-b977-58e0-8cb9-a10680c58bec', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 75, 4288.4, 848.6),
('5d5ded87-42e3-515a-bda8-6494b1040e1e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 76, 4286.5, 850.9),
('ce134a8c-55ad-5f17-ac04-0fd0c66a858e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 77, 4284.7, 853.3),
('36af82e7-f144-53c9-a424-fb7eca45d820', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 78, 4282.8, 855.7),
('a3d08771-aa6b-508f-a942-d71166fc5cfd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 79, 4281.0, 858.0),
('aee42d88-586b-5008-ac91-cc0ed46f4df6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 80, 4279.2, 860.4),
('ae640274-4f8f-561d-b767-4985422f370d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 81, 4277.3, 862.8),
('b5ceaa36-33e7-50f4-a2ee-6998903e3109', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 82, 4275.5, 865.2),
('87436374-bbe2-5842-a3ff-16a33062b9c7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 83, 4273.7, 867.6),
('bc66ddaf-f272-527e-b9bc-4f3bffa1e377', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 84, 4272.0, 870.0),
('a0dc18c9-713f-5bb5-9ee6-8201e7f053b0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 85, 4270.2, 872.5),
('60c66585-5d9f-5607-a124-8bba5471343a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 86, 4268.5, 874.9),
('2661f75d-e1f9-59b8-b29f-021b7a4b2aac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 87, 4266.7, 877.3),
('df2f2c01-643c-54f2-9da7-d5af6b413c97', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 88, 4265.0, 879.8),
('3e2571aa-3f25-54f1-95bd-7d3451531aff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 89, 4263.3, 882.3),
('676c44ea-0412-58a6-943c-65658aed1c2f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 90, 4261.6, 884.8),
('b131f1a3-cf58-567c-baf7-bcb619cad877', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 91, 4260.0, 887.3),
('d5f3348e-a028-59c9-8424-be0dff93a978', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 92, 4258.3, 889.8),
('0dd3847f-2180-5ed8-93f8-a9b85ca315e3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 93, 4256.7, 892.3),
('d03ad6fd-d40f-53fa-9043-233e560b7554', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 94, 4255.1, 894.8),
('d079664e-781f-5787-95db-a89665b96550', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 95, 4253.5, 897.4),
('cc39371a-3b59-5816-82b0-5f93b83cc616', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 96, 4252.0, 899.9),
('2b8ac81b-a554-5c18-9509-edcc09ebd5ed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 97, 4250.4, 902.5),
('4b526bee-be26-5bf3-8b39-a4c6a300fca3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 98, 4248.8, 905.1),
('6c6ad721-1a26-5b10-8d0c-3dc84eebcc25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 99, 4247.3, 907.6),
('95d4b951-be74-5403-88ae-0ef809d90c70', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 100, 4245.7, 910.2),
('5ff5ca94-98aa-5d1f-8188-738e4480a6e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 101, 4244.2, 912.8),
('24f467c0-3018-546c-ba65-1e8cff977fa7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 102, 4242.6, 915.3),
('32f72f36-c32d-5e06-ab1a-0ba10fe0061a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 103, 4241.1, 917.9),
('71e1cd57-d007-544b-b96f-84ad839ca2d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 104, 4239.6, 920.5),
('6d716320-2e7c-5e1a-85cc-444aab92467c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 105, 4238.0, 923.1),
('049bd0fb-c361-5ac5-bcb5-18c4d8dd1404', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 106, 4236.5, 925.7),
('f0fdf44b-c912-5459-806e-4b28c9fca3c8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 107, 4235.0, 928.3),
('e48adb7a-c366-5800-970b-ecc70f46bdc2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 108, 4233.5, 930.9),
('ced37772-b771-5c74-96c8-55b165498d46', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 109, 4232.0, 933.5),
('d61bdde8-a793-547f-b62c-852bfe1e3483', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 110, 4230.5, 936.1),
('72eb5ce7-f52e-5bc5-bf51-2e0aa9d814b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 111, 4229.1, 938.7),
('243182df-f451-5d58-b463-e484b3570b67', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 112, 4227.6, 941.3),
('8cdaf2c0-1308-5e0d-8787-10da4434bd03', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 113, 4226.1, 943.9),
('e47fe941-a81a-5e50-9150-802970a6a43a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 114, 4224.7, 946.5),
('cc3971a5-3d8e-5e0e-9818-df52ca94d55c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 115, 4223.2, 949.2),
('c4e1c74c-05cb-5dfc-9f35-8e5f2c1edf87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 116, 4221.8, 951.8),
('fcff4d31-5213-5330-b3fa-9a992c0a33ac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 117, 4220.4, 954.4),
('ebac9b28-22f0-5f37-8a46-a169dbc784cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 118, 4219.0, 957.1),
('9f016c6c-6e63-5275-9d88-a8e09bdb16b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 119, 4217.6, 959.8),
('49f9b175-b590-5480-869f-170d5e14b7f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 120, 4216.2, 962.4),
('5945172b-719c-5c1e-aeac-aae85a937c31', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 121, 4214.8, 965.1),
('0d918154-9970-5ff1-845a-0791168b1120', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 122, 4213.4, 967.7),
('28ff9007-f920-53a5-bbb3-96d00b0a4d72', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 123, 4212.1, 970.4),
('c4bd2519-77a0-5e75-8a94-f5445463cbb7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 124, 4210.8, 973.1),
('f2957256-50ed-5dde-adcb-aeebffb81a6d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 125, 4209.4, 975.8),
('1104e2c3-f121-5109-bd6c-acff85ab9c89', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 126, 4208.1, 978.5),
('45630036-882e-53c1-b100-16d476fec9fa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 127, 4206.8, 981.2),
('1282144e-bb32-57e2-bff6-15d68cc0d38f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 128, 4205.5, 983.9),
('692340b2-efb2-5e58-b56c-5cf0f452405f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 129, 4204.3, 986.6),
('47bdc24f-0f76-5cc2-81bc-6ff21bc16f47', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 130, 4203.0, 989.4),
('4c37b2f5-db04-51bf-b2b7-76a95cc8b559', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 131, 4201.8, 992.1),
('f9e64b99-70e7-524a-96ab-92e10e72ec56', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 132, 4200.6, 994.8),
('bc3cede4-a5f9-5154-87e7-af4cf33abec0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 133, 4199.4, 997.6),
('e2920015-d8eb-591c-a309-c7e1c109b509', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 134, 4198.2, 1000.3),
('451416f3-28df-5f36-88b2-3d6f0035eef7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 135, 4197.0, 1003.1),
('13c54f8c-f30d-5579-aa2b-18efe8e7e2a3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 136, 4195.9, 1005.9),
('315a5198-228b-592b-996c-41a2a9a71a7b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 137, 4194.7, 1008.7),
('8c2cc0bc-2182-5558-85b2-2ebc23a2eabb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 138, 4193.6, 1011.5),
('ae7c641d-8378-5f0e-a811-0f445d8ce725', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 139, 4192.6, 1014.2),
('acb8a546-5e70-543c-a9d0-0a654a2c2c91', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 140, 4191.5, 1017.1),
('9207e71c-add7-582f-8f2c-e715991f3418', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 141, 4190.5, 1019.9),
('928e5833-e0ff-5d7b-8c4e-27d8e42bb0c8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 142, 4189.5, 1022.7),
('6bf8bd60-43f0-5bcd-9dee-78ac775e11e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 143, 4188.5, 1025.5),
('d729001a-b152-571c-a47c-2413ed89e9d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 144, 4187.5, 1028.4),
('03d9fd3c-e5a0-5939-9998-6bbf4947b65a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 145, 4186.6, 1031.2),
('d1eea565-3874-5d4f-9787-9388dc529f07', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 146, 4185.7, 1034.1),
('a42183df-bc89-5494-bc41-09f665cac89c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 147, 4184.8, 1037.0),
('42417120-6ad0-518e-947b-84850a7d8d0f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 148, 4184.0, 1039.9),
('9097efac-b35e-58ee-acdf-9b19cafe1883', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 149, 4183.3, 1042.8),
('03d9004a-0115-5071-adb4-d90edc83a200', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 150, 4182.6, 1045.7),
('f125e531-4661-569e-8390-0b0b7548be4d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 151, 4182.0, 1048.6),
('487269fb-71c5-5305-b151-2575350969ee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 152, 4181.4, 1051.6),
('325635de-cdc3-55cc-aea1-97e169588932', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 153, 4180.9, 1054.5),
('ef35dac6-9d56-52d8-a1e6-c9c3bbdafe72', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 154, 4180.4, 1057.5),
('865549ec-4510-55f8-84e8-546c29c8bff4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 155, 4180.0, 1060.4),
('c34dd6f1-5d2f-5092-ba59-eadbe6727aa5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 156, 4179.6, 1063.4),
('26b0a91f-7605-545a-a85a-f3a6ef3d174c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 157, 4179.2, 1066.4),
('6e92c7e6-575d-5eb3-aab4-c31aeac6d2ee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 158, 4178.9, 1069.4),
('313ddfe8-29f5-5d87-8821-d88d59568ba0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 159, 4178.6, 1072.4),
('40ec4d85-b0d8-5046-99cd-7f30fd833b89', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 160, 4178.4, 1075.4),
('d36d44c1-e926-5ad3-aad7-19e46e86a6d3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 161, 4178.1, 1078.3),
('ec34c216-869c-5b21-aa5f-f009a5392fab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 162, 4177.9, 1081.3),
('018a9a91-fd6c-5137-9a1d-3152e4295cac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 163, 4177.7, 1084.3),
('8de82d54-a620-5138-ae62-eee9660513eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 164, 4177.6, 1087.3),
('8dc9bc35-daca-51e0-8012-e18242fe7e57', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 165, 4177.4, 1090.3),
('a4e5a3a1-4c97-5c44-a3f5-cef865001d81', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 166, 4177.3, 1093.3),
('c24b1967-dc7a-518e-a507-a7b5b6e997c9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 167, 4177.2, 1096.3),
('1a7d2a22-495d-5f76-96a1-792f533c861c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 168, 4177.0, 1099.3),
('73082ffd-ffe9-5ade-b4d8-060c875916a5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 169, 4176.9, 1102.3),
('de0cfb6e-ebbb-5604-91a8-5a7af7745a28', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 170, 4176.8, 1105.3),
('e8edcf49-434b-5538-9e3e-b54159521b25', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 171, 4176.7, 1108.3),
('61c67ed6-0169-5ac5-9f18-a0317b767dd5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 172, 4176.6, 1111.3),
('991fa1a8-e470-5923-b63c-de109bad06e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 173, 4176.4, 1114.3),
('d54c43bc-7c36-55b6-9f49-38181978e667', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 174, 4176.3, 1117.3),
('19e774ed-38cc-51a7-b5e9-ba265c420fcf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 175, 4176.1, 1120.3),
('05c38374-ea3e-58fb-b0c8-e8c556b3eb75', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 176, 4175.9, 1123.3),
('66136dff-fd9d-512d-9c13-ae4b13c85431', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 177, 4175.7, 1126.3),
('06f117ec-2f4a-5fa2-a7d7-5974ea7e842c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 178, 4175.5, 1129.3),
('257199ba-94ac-5605-81f7-a6ab0f78ca12', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 179, 4175.2, 1132.3),
('b503b6b9-9301-51de-9a92-5fe28e179f6e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 180, 4174.9, 1135.2),
('830c0d45-3637-582b-90ae-848bf5c351e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 181, 4174.6, 1138.2),
('bb5af389-c110-5d29-b23e-bce2ca087057', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 182, 4174.3, 1141.2),
('f1874d49-9dc3-56d3-93f4-a1d6b9834ff9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 183, 4173.9, 1144.2),
('b7df0760-cbcf-5a80-b840-4311b6c83fd5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 184, 4173.4, 1147.2),
('f4056aef-f915-5cf4-a9df-4da75269050b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 185, 4172.9, 1150.1),
('83a8e5b7-9ac3-53d1-b51c-bc21d5426378', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 186, 4172.4, 1153.1),
('2e4d0b25-ef16-586b-be5a-1f43a9c80be9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 187, 4171.8, 1156.0),
('42043197-ea7c-5857-a5e4-f89a4acb4c98', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 188, 4171.2, 1158.9),
('955aaef0-d507-5e62-9f0f-ac5c4004c4ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 189, 4170.5, 1161.9),
('a7e81ae2-61d1-54de-ba06-916e722603bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 190, 4169.8, 1164.8),
('0815433a-577a-5073-a020-99a301471a55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 191, 4169.0, 1167.7),
('cca9bf9f-ecaa-5329-a282-3cc0864ea753', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 192, 4168.1, 1170.5),
('c162c362-1159-59a4-8198-76bb00d8ff33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 193, 4167.2, 1173.4),
('ed081367-5286-5064-a997-abb75de5cd01', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 194, 4166.3, 1176.2),
('c46ca092-6632-52b0-ab32-277d4493de16', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 195, 4165.3, 1179.1),
('052b92fe-777b-50d6-a020-751d24830bd8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 196, 4164.3, 1181.9),
('0db26ed7-3cab-5e02-b02d-c81c01a4ed6f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 197, 4163.2, 1184.7),
('c9a2138a-c236-5473-b48c-ac14c9ad5249', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 198, 4162.2, 1187.5),
('b081866a-b178-5946-90be-7b5696111fd2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 199, 4161.0, 1190.3),
('bdd2421e-1bbd-50b2-a7ad-8c34c866b59a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 200, 4159.9, 1193.1),
('4dbb2272-6d81-51c4-ac52-09aac8f8479c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 201, 4158.7, 1195.8),
('78c19ed5-9787-571c-b813-c3771bac193e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 202, 4157.5, 1198.6),
('5340d207-6c74-5c31-ab4f-30f0e39a043b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 203, 4156.3, 1201.3),
('317dfdec-e622-53dc-81f4-ba39c9cced5e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 204, 4155.1, 1204.1),
('772beeca-9d0c-50b4-bfac-d137638fb977', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 205, 4153.8, 1206.8),
('36dd272a-86e8-59cc-8568-c959b20ed0cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 206, 4152.6, 1209.5),
('400453b4-8980-56ad-9a9f-443d94237f2e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 207, 4151.3, 1212.2),
('1131a419-42a3-5280-bcff-c5763ff51f33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 208, 4150.0, 1214.9),
('e5a0dc6e-c408-5499-8224-11499d10e04c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 209, 4148.6, 1217.6),
('ac1edf30-8845-52b0-bf22-e944cfab005c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 210, 4147.3, 1220.3),
('c26f3615-a418-56ce-9af2-e49fa95ee5fb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 211, 4145.9, 1223.0),
('ab0c82b0-7938-5687-bad5-17d2df4445cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 212, 4144.5, 1225.6),
('f2d7c869-f523-58b4-ad7d-daa63e6f56b2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 213, 4143.2, 1228.3),
('363d30b0-587d-5dd4-81d0-572ca89bd983', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 214, 4141.8, 1230.9),
('d64b7782-24c7-514c-a3b9-e057a91c9dc7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 215, 4140.4, 1233.6),
('b6a66db8-eacf-5dbc-9b52-a47e6af05828', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 216, 4138.9, 1236.2),
('faedf850-1411-5fc6-9315-3efeada44a85', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 217, 4137.5, 1238.9),
('03f70282-7a9b-5ff7-abee-fbd63db1e53e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 218, 4136.1, 1241.5),
('7a9a6d02-80d8-5ea1-ad56-f9d742851a26', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 219, 4134.7, 1244.1),
('4d1ff4a9-2d54-5c2d-9c5d-39bc1681018a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 220, 4133.2, 1246.8),
('ca89fa6f-5023-54bb-bb9a-a95d6c73a92e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 221, 4131.8, 1249.4),
('01bf333e-56cf-5875-a321-69ff8473d45f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 222, 4130.3, 1252.0),
('bc176e6a-6cd4-5e49-b094-2257ebcd00b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 223, 4128.9, 1254.6),
('fd8e9492-faa2-51b6-88cd-b4eedbce38bc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 224, 4127.4, 1257.3),
('c26ce645-91a7-58b1-a1c7-7934057098de', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 225, 4125.9, 1259.9),
('940ebd63-3dd1-57ff-adc0-4930004286f1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 226, 4124.5, 1262.5),
('1780a317-405f-544a-92c6-ac54f509261c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 227, 4123.0, 1265.1),
('541d27e4-185b-5b21-b449-733aff370683', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 228, 4121.6, 1267.7),
('f56be2ae-4418-59f4-8130-70755651d353', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 229, 4120.1, 1270.4),
('16f65d1a-fd20-54fa-9fb2-2b87476b6c95', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 230, 4118.6, 1273.0),
('1a977420-b166-5b4b-b30a-540ecb42e190', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 231, 4117.2, 1275.6),
('0ce7c40f-5f60-508e-8369-ef9f0cd46aff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 232, 4115.7, 1278.2),
('608ad045-e17b-52e9-9866-b6188166f04a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 233, 4114.3, 1280.9),
('c4672cda-f28a-54ff-901f-ea4ca9edd458', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 234, 4112.9, 1283.5),
('f7aa34eb-e276-554a-bf2c-411c319461c0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 235, 4111.4, 1286.1),
('b33a04ca-93c5-57ff-9043-e1080aba96a7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 236, 4110.0, 1288.8),
('1b32b7fc-f346-5f4f-a04f-59373833ee8d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 237, 4108.6, 1291.4),
('435cfdc0-3418-53ee-afad-f4c6e806f278', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 238, 4107.2, 1294.1),
('68d11238-593a-569e-b93e-1ad2c128729d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 239, 4105.8, 1296.7),
('d7ae6bb1-6c35-5399-b6f4-c4febc5d6945', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 240, 4104.4, 1299.4),
('b1881496-5186-5cc1-8a1a-aef8eabd4f19', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 241, 4103.0, 1302.1),
('90e1cc02-81c3-5e43-9efd-eb72bcb6ef9b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 242, 4101.7, 1304.7),
('51631280-67bb-5479-ab29-eaaf23f9f450', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 243, 4100.3, 1307.4),
('f9097d45-2140-5f7e-aa8a-dd0136dad091', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 244, 4098.9, 1310.1),
('af9e52f1-5a05-5d88-9c53-071bf64c604e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 245, 4097.6, 1312.8),
('f187931a-9915-573c-901e-70626e2ba5b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 246, 4096.2, 1315.4),
('c2659d78-2c77-52b4-86a9-2ac70144a40b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 247, 4094.9, 1318.1),
('9ae059a6-4a0d-5ad1-8714-f45122d093d1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 248, 4093.5, 1320.8),
('9e26d92a-c465-560a-b55e-0d1641d78028', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 249, 4092.1, 1323.4),
('8144861d-c942-5d87-bc8d-ec9adce52b7b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 250, 4090.7, 1326.1),
('f61c0e32-fa0b-578a-9564-d9c02744f394', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 251, 4089.3, 1328.7),
('52e302b0-df39-52d1-b90b-7b5dbfce4ca5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 252, 4087.8, 1331.4),
('b458bd42-d243-5c62-b977-d3e26d54d148', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 253, 4086.4, 1334.0),
('f0c39941-4109-5998-b2a8-a42edaf25bcf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 254, 4085.0, 1336.6),
('97fea8ce-f8e0-580d-adc3-b17a5400be5d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 255, 4083.6, 1339.3),
('850ccfd7-e421-50d3-bd1e-b3a1916c90ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 256, 4082.1, 1341.9),
('3137f2fc-0e70-5d80-b18c-41864b16c49a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 257, 4080.7, 1344.5),
('e93139a8-b978-59ae-a35f-389cf6022fae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 258, 4079.2, 1347.2),
('6788a293-0208-5adc-bc68-8814e68a24f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 259, 4077.8, 1349.8),
('9dc8194d-76ef-5750-96d6-98a4dc3fde7e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 260, 4076.4, 1352.4),
('84d18844-77d4-55dd-8b76-f670fbe8d57f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 261, 4074.9, 1355.1),
('37dd2fa9-c2f6-5b37-bc1e-d4444ceeff36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 262, 4073.5, 1357.7),
('edbdb9e7-464a-511a-8c32-f39de1e1942b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 263, 4072.0, 1360.3),
('707ad374-d68c-5893-b2c6-f7cacaccd3cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 264, 4070.6, 1363.0),
('779e5d81-87ba-5425-aea9-a2f88c08ed2a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 265, 4069.1, 1365.6),
('58cc275c-ddff-58b6-a3fc-41ab680cbf2e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 266, 4067.7, 1368.2),
('e384b6cd-cdb6-5d48-9221-86ba900bf98f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 267, 4066.3, 1370.8),
('8c52e531-a4d7-5b70-9121-a71085025b44', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 268, 4064.8, 1373.5),
('31beadec-013b-5d88-9bee-0f5850f2ab18', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 269, 4063.4, 1376.1),
('14f20993-20d0-5702-8bb6-1e8dde52d254', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 270, 4062.0, 1378.8),
('890c4318-4168-569d-bd99-0823502a40bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 271, 4060.6, 1381.4),
('6b727ebe-18bf-5e58-ad5b-ba1bc011cfab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 272, 4059.1, 1384.1),
('d65f2ed6-ef86-5c10-850f-a0a68f118303', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 273, 4057.7, 1386.7),
('bf9ba848-8605-515f-b6b5-35cd0375093f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 274, 4056.3, 1389.4),
('71a79f95-86c5-5c34-be03-a0ff2ef0786f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 275, 4055.0, 1392.0),
('32231373-9a60-54bf-aa93-e0a27e6e5ed0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 276, 4053.6, 1394.7),
('2a22237b-1479-502a-9eb9-d64e8c2fafe8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 277, 4052.2, 1397.4),
('97caca16-2f75-5f19-8978-d0f66bded477', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 278, 4050.9, 1400.0),
('d0aa7f93-b7fb-5e0f-8322-631b99a487d1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 279, 4049.5, 1402.7),
('540320f6-ae70-5a0d-b2cd-7780f0513f82', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 280, 4048.2, 1405.4),
('5a34d31f-1aba-5208-85af-b1f52cc46419', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 281, 4046.9, 1408.1),
('d36cad9f-ff65-5d31-a552-811277212b22', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 282, 4045.6, 1410.8),
('4690dfbd-1896-5be7-b067-712ce3388713', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 283, 4044.3, 1413.5),
('1dd1946f-8810-520f-b595-1d53388a06ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 284, 4043.0, 1416.2),
('2a27a481-da03-5739-891b-b5f313fcb81f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 285, 4041.8, 1419.0),
('6796d946-4578-5723-bba6-14c7cf2c4d40', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 286, 4040.6, 1421.7),
('8dc8ec11-b9bc-5a67-9a8d-2386abd63a6a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 287, 4039.4, 1424.5),
('e4101ed5-beac-5a4f-8526-8b48f8f9d7e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 288, 4038.2, 1427.2),
('6bf3499a-7acd-5737-bf18-32860e7ee1d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 289, 4037.0, 1430.0),
('c9c5315d-4611-5d52-b726-6f01c701d132', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 290, 4035.9, 1432.8),
('fac1a449-b172-5272-88c7-757f2736e444', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 291, 4034.8, 1435.6),
('1b4bb14c-814d-54f9-88d9-3c6a38219151', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 292, 4033.7, 1438.4),
('5b0b69ac-a8e2-53ad-888e-4bb4a88ffde0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 293, 4032.7, 1441.2),
('7d3f386e-96b5-5557-968f-e614a17c3910', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 294, 4031.7, 1444.0),
('7d748fa7-8bfc-5309-bffa-2da65e44e5db', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 295, 4030.7, 1446.8),
('4814c69f-4f01-5259-9ec4-f29bef244745', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 296, 4029.9, 1449.7),
('d40f8b8e-59c2-5653-bf7a-7f7c4add753d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 297, 4029.1, 1452.6),
('e7619646-d74f-51c5-8cf3-795f020a23d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 298, 4028.3, 1455.5),
('5fd3e95d-c64e-5f24-8769-f0c796be3e2d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 299, 4027.7, 1458.5),
('3b1b9699-da8c-5f10-81ee-2c6852577aa8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 300, 4027.1, 1461.4),
('e13143d0-bdac-5d29-a100-a0001e07a72a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 301, 4026.7, 1464.4),
('7da1ba4d-1efb-5785-85af-603409da686b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 302, 4026.2, 1467.3),
('4fece78e-3939-5c46-917e-ebd6ada6df63', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 303, 4025.9, 1470.3),
('da2e0dbe-2be4-5328-a8cc-89a55bd972da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 304, 4025.6, 1473.3),
('44da360f-261f-58cd-a7da-7ebd41c862bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 305, 4025.4, 1476.3),
('ea4e8a4a-4719-5aa3-9d50-435fdbbd5bdc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 306, 4025.2, 1479.3),
('1296d71f-ad93-50f9-b238-958365d528f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 307, 4025.1, 1482.3),
('5e1995dc-1b02-5d64-8123-dfaa9b66f3f6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 308, 4025.1, 1485.3),
('f78d7087-a664-5f72-9d63-c7ecbd401ac0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 309, 4025.0, 1488.3),
('e6736d6c-f1af-5a57-9ac3-4b6e057f81df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 310, 4025.0, 1491.3),
('5a43977b-1783-54af-82e2-a207f6f347a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 311, 4025.0, 1494.3),
('dc051e73-a8fb-55b3-984a-14b539807221', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 312, 4025.0, 1497.3),
('882df383-b024-5da4-9f24-bc79292be961', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 313, 4025.1, 1500.3),
('3d6e409a-da66-5824-83a2-f7965d1da7ad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 314, 4025.1, 1503.3),
('3805025b-e7b6-5d17-a6ae-6f1a8a73cc41', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 315, 4025.2, 1506.3),
('e0ddcdc4-83a7-5f33-bce1-4477f5a4eb36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 316, 4025.2, 1509.3),
('46285104-16b0-5c8b-8942-fc4f48993275', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 317, 4025.2, 1512.3),
('83389abf-e860-53dc-a213-0f3c46111b7e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 318, 4025.2, 1515.3),
('1e2e3fc1-46d8-51d4-a216-a91032988950', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 319, 4025.2, 1518.3),
('3bef7c62-3d73-5289-91f1-96b6aeacac20', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 320, 4025.1, 1521.3),
('6755080a-ba0c-5b68-ba6b-27de323e86cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 321, 4024.9, 1524.3),
('d7f4ca6a-b4f1-5828-b224-6f551af8e70d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 322, 4024.8, 1527.3),
('472edd6f-5fa6-59c6-8c92-179d8cb3b47f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 323, 4024.5, 1530.3),
('45bbdb4c-e9a4-5b37-ae90-1aa7ae27b608', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 324, 4024.2, 1533.2),
('4e071268-278d-513b-8fce-205035da6812', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 325, 4023.8, 1536.2),
('b28cad77-f394-56e9-8a8c-dd6f23f129f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 326, 4023.3, 1539.2),
('a7151f29-f231-570d-a286-4cc5f8711555', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 327, 4022.8, 1542.1),
('52d2e853-12ac-57ee-9a3b-a74f2b4d241a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 328, 4022.1, 1545.0),
('c1eed5f9-c423-539e-bd47-6323363d01d4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 329, 4021.3, 1548.0),
('b4a95432-2421-5f72-8b7c-97fc63fdbcb1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 330, 4020.4, 1550.8),
('485c703a-2afc-5c58-b045-3ef28ea78285', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 331, 4019.5, 1553.6),
('9e78be80-ae0d-5e94-af81-1de725e3957e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 332, 4018.4, 1556.4),
('564caa06-6918-50cf-8e0d-f23113119cb4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 333, 4017.2, 1559.2),
('5807c3c3-d426-555a-a15a-152fe65b6cfc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 334, 4015.9, 1561.9),
('4b878767-4ebd-50a9-b649-9e5e5344220f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 335, 4014.4, 1564.5),
('9865ab79-6e38-56fa-83eb-2f298b7996f8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 336, 4012.9, 1567.1),
('ebb0f817-0ac9-528f-8c8d-89704f4fbba3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 337, 4011.3, 1569.6),
('35a6e209-3490-56b3-96ac-fa16b9aaf335', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 338, 4009.6, 1572.1),
('05705578-0c67-5bf0-b82b-bd773c75bfaf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 339, 4007.9, 1574.6),
('32a0d471-0f89-553b-9c52-c2003d9352e2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 340, 4006.1, 1577.0),
('1a993b32-6ad3-5cc1-ba1a-6ff539b68047', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 341, 4004.3, 1579.4),
('9536a332-83fe-53b9-9d56-be846023016e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 342, 4002.4, 1581.7),
('3fd78e70-13b1-5b46-912e-5e8a8e01356a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 343, 4000.5, 1584.0),
('072c7c02-faa2-50fd-adba-5fee86ee7271', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 344, 3998.5, 1586.3),
('02a05906-f480-5c0d-b1bb-2c6b9b2035fd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 345, 3996.5, 1588.5),
('ea09e9e0-da6c-551a-82bc-f26a126ae081', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 346, 3994.5, 1590.7),
('27eb4ffa-1d56-5b22-b93f-d05fb554a196', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 347, 3992.4, 1592.9),
('79d8e27e-4555-5ecc-898d-a0f016839da7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 348, 3990.3, 1595.1),
('f54ed157-2efa-554d-86ce-2548e1736580', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 349, 3988.2, 1597.2),
('d0dcc73e-a8e6-5ea1-bfdb-c6c019a9ae84', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 350, 3986.1, 1599.3),
('2ea3a11f-8cd1-5467-9a7a-1260a9e46f9e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 351, 3983.9, 1601.4),
('bacfbecd-154c-5a26-b23d-62519f88b2f4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 352, 3981.7, 1603.4),
('e20cc050-b04c-54d1-9503-7b5e0801d6e1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 353, 3979.5, 1605.5),
('076919c2-4286-5993-90f7-360287b99c11', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 354, 3977.3, 1607.5),
('5afebfce-a95b-5785-85ec-ea17fe5bb18e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 355, 3975.1, 1609.5),
('7c2104f9-107c-5091-8a4a-97f3435b089b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 356, 3972.8, 1611.5),
('aa491cca-8229-568b-9d54-d682d1e14cbc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 357, 3970.5, 1613.4),
('d7b517cb-8366-5292-a285-cb60cfae757b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 358, 3968.3, 1615.3),
('401ba109-aa7d-5d04-8033-9b742b07ea0e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 359, 3966.0, 1617.3),
('468aef8d-74aa-5185-990a-199b928f4739', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 360, 3963.6, 1619.2),
('6c029e15-aadb-50d2-97f8-1e5c35fdffe8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 361, 3961.3, 1621.1),
('5b3856b8-ec14-5519-8550-ae69cfb38be8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 362, 3959.0, 1623.0),
('f7fe2eef-631f-5ae9-8ca9-d8eadd885349', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 363, 3956.6, 1624.8),
('f5c63315-17e3-5a1a-8ccc-3d65137389ec', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 364, 3954.3, 1626.7),
('9ad2eafd-2aee-5ff4-8dd1-9841b65c694c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 365, 3951.9, 1628.5),
('cff083c9-c175-56df-88ac-bb4f6260eea7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 366, 3949.5, 1630.3),
('91009259-2779-5f47-9841-9c2f1f19f950', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 367, 3947.1, 1632.2),
('6640a39a-bc39-5d80-ac45-277eea02da8b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 368, 3944.7, 1634.0),
('494c539b-66cf-5ebb-9db0-98ce8e0d13c5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 369, 3942.3, 1635.7),
('ae045ed7-7888-51ea-ac2c-fced8b14e4b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 370, 3939.9, 1637.5),
('bfa52d2c-0ac3-5edd-86a1-c0de12782c3f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 371, 3937.5, 1639.3),
('3629ba91-94e1-5477-82f0-41722734ce5d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 372, 3935.1, 1641.1),
('67dc5972-9f41-5e3f-9d5e-5f7588606d65', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 373, 3932.6, 1642.8),
('d0693305-c409-5f97-a26c-a0aebd158329', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 374, 3930.2, 1644.6),
('24b8de27-e914-5e38-8330-76a513804a9f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 375, 3927.7, 1646.3),
('08cc2f0c-00a8-5e97-ab0b-24664ec7b901', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 376, 3925.3, 1648.0),
('7f05575f-6bc6-5f0e-9b31-a87024b46627', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 377, 3922.8, 1649.7),
('8b4d4e10-9a8d-5462-b2dd-e2e8de87df31', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 378, 3920.4, 1651.5),
('be9885fd-00b4-57a7-b0c2-55496870945c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 379, 3917.9, 1653.2),
('30f38b4f-6f86-5d16-b27d-089f49d3aa04', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 380, 3915.4, 1654.9),
('98c62d8b-8eca-5aee-a630-c64fee3202ee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 381, 3913.0, 1656.6),
('c9ac143f-5f01-5481-8126-e0aa44ab74c2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 382, 3910.5, 1658.3),
('51db04d9-49eb-5987-afae-7250970ecdb0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 383, 3908.0, 1659.9),
('79a826a5-dddb-52a8-af27-55bcd21841f5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 384, 3905.5, 1661.6),
('32fab3ca-be72-57b8-b11f-630ab5afd2de', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 385, 3903.0, 1663.3),
('35e6484f-fc5a-5d1a-93dc-94a34bc7e171', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 386, 3900.5, 1665.0),
('ce6cf5f2-9cb2-55ba-a2da-105357f19dc5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 387, 3898.0, 1666.6),
('10650adb-c3eb-57c5-95e2-711c05c54719', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 388, 3895.5, 1668.3),
('04c8bed3-52ac-5644-83ff-7c95c04d28d9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 389, 3893.0, 1670.0),
('51dd7914-3ec4-5249-98b3-7e10807f69fe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 390, 3890.5, 1671.6),
('520dee47-5181-5a5b-826b-bfec5c28c2df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 391, 3888.0, 1673.3),
('5ef30cb8-1f13-5bda-8161-4ba461fb154d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 392, 3885.5, 1674.9),
('57831e55-fe38-5147-b05a-592db4ec7268', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 393, 3883.0, 1676.5),
('f9bc5e93-3491-598d-8202-390cd6080018', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 394, 3880.5, 1678.1),
('43c1bc0b-4ac6-597f-b764-e0417bcb7af1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 395, 3877.9, 1679.7),
('a004f544-a8d7-5360-87d0-b22d52249d36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 396, 3875.4, 1681.3),
('334c3672-2282-5971-a189-013adba21944', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 397, 3872.8, 1682.8),
('fb21b4c4-efec-537b-9084-5a96b82fc824', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 398, 3870.2, 1684.4),
('ef1a003b-799d-5f18-8834-a20ffe6d3582', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 399, 3867.6, 1685.9),
('3025495a-d7d9-5f73-bbb8-9e5ab56e9362', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 400, 3865.1, 1687.5),
('8d6924d3-fd65-599c-a867-9763fddda838', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 401, 3862.5, 1689.0),
('c941d3e7-e539-5163-9970-daf3df3c2c3e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 402, 3859.9, 1690.5),
('2f6ca24f-c6e2-509d-9df3-e79eba1b6370', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 403, 3857.3, 1691.9),
('2dde0b19-15d5-5783-8892-fd66f87c01a0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 404, 3854.6, 1693.4),
('8e062118-3030-55c3-9ec4-03d88ca4d271', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 405, 3852.0, 1694.8),
('f7e1e3f6-c115-52bd-9483-6f479d8e04ba', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 406, 3849.4, 1696.3),
('bd821a5c-f28e-539c-b006-93c0491cf7be', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 407, 3846.7, 1697.7),
('7a0307eb-c337-520c-b373-78d1667f2fba', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 408, 3844.1, 1699.1),
('eee62948-7819-5684-9a8c-9c79b63de0d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 409, 3841.4, 1700.5),
('38aa946a-87b6-5f09-8858-8c4d40b9d0a4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 410, 3838.8, 1701.9),
('1265214a-3bd7-5697-b72f-94919efa82c4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 411, 3836.1, 1703.3),
('18bcf79c-73df-58cd-a868-a65ce0df7b33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 412, 3833.4, 1704.7),
('3defbf0b-8acf-5384-b45b-101b3a54fe16', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 413, 3830.8, 1706.0),
('b89f5b2b-55e5-57ff-95ad-702ec3f9129d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 414, 3828.1, 1707.3),
('3c68d791-2ca9-53f0-a158-5db513a4d10e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 415, 3825.4, 1708.7),
('b3551b78-6670-5d65-a4fd-ee5bfeb7fb52', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 416, 3822.7, 1710.0),
('cc7bbf28-7357-5f5a-ba9c-3ccdf68fe4de', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 417, 3820.0, 1711.3),
('020efb5e-51b0-5b6e-b992-7155a1ede5e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 418, 3817.3, 1712.6),
('b6b7b84e-793e-547d-a11c-8fcc9c0399f1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 419, 3814.6, 1713.8),
('f5759273-1ab0-5e4b-85ed-d5c71ee7f49d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 420, 3811.8, 1715.1),
('02490716-7a2c-5a3c-a7a9-cc160329a5c8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 421, 3809.1, 1716.4),
('3969c5b2-bb24-591c-b062-bad38ce3acdf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 422, 3806.4, 1717.6),
('c7d746ca-30af-58ce-acd4-a68a2eb89721', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 423, 3803.7, 1718.8),
('932e90af-928d-500c-895f-20c228374ea1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 424, 3800.9, 1720.0),
('aaa35608-53ac-54eb-b911-45d3c30e174d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 425, 3798.2, 1721.3),
('389c57b2-246b-5c52-86ae-13fcb8f9212b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 426, 3795.4, 1722.5),
('7e8962f4-8dcb-5884-ba7b-411b415c432a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 427, 3792.7, 1723.7),
('b42c4f1a-a442-50dc-abe1-448ea59ac84e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 428, 3789.9, 1724.8),
('f165fade-5684-5d18-9e9a-729daf6a9aa9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 429, 3787.1, 1726.0),
('7610fded-c93d-5398-abed-bf2262bf2e11', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 430, 3784.4, 1727.2),
('5a60cc8b-120a-5ee4-be7d-c1d78b808ae1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 431, 3781.6, 1728.3),
('4c1b5aff-9a87-5a27-ae59-5af1d4544677', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 432, 3778.8, 1729.5),
('02051ca0-519a-55b5-a3ce-503dba4312f8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 433, 3776.1, 1730.6),
('de36f088-e4f1-56e6-acb0-3a23dc70def7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 434, 3773.3, 1731.8),
('90d448d2-05cd-5b66-8a71-9dcaa7d5eb82', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 435, 3770.5, 1732.9),
('62e16e21-f33b-5016-ad6e-5f6b963552d5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 436, 3767.7, 1734.0),
('6aba020d-64e6-59e5-ac01-90bada1b73cf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 437, 3764.9, 1735.1),
('da9b3e51-b13e-513b-b034-ccd23a304ee9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 438, 3762.1, 1736.2),
('d4fd77e2-14b4-5e1b-8977-4e2544b92b33', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 439, 3759.4, 1737.3),
('97118f4e-ceed-53e9-becb-45c2e2d82f01', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 440, 3756.6, 1738.4),
('7273907f-a363-5b6d-a25a-933dedb8b93a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 441, 3753.8, 1739.5),
('05b21c09-9326-571c-99ca-8683f0e62c50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 442, 3751.0, 1740.5),
('fd707de5-d6f9-54d6-9f65-b6c04aadd9a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 443, 3748.1, 1741.6),
('6fa043f7-0eec-5cb1-8c37-39713e1fa2c0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 444, 3745.3, 1742.6),
('ef18127f-8f8f-5799-a2f3-d461b3014419', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 445, 3742.5, 1743.7),
('929b4bdc-c449-5351-a185-92d73e6c5dcd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 446, 3739.7, 1744.7),
('1657edc6-a14d-50d0-abcf-e43fb5fb66e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 447, 3736.9, 1745.7),
('9e75813c-db89-5d5d-a688-d3ecc49dced3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 448, 3734.0, 1746.7),
('08cd395b-adc6-57a3-a78d-a1f591672add', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 449, 3731.2, 1747.7),
('f5727e00-1697-53ac-a4f1-b17cf9c91afb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 450, 3728.4, 1748.6),
('971aa3a5-68b4-5c43-9a7f-eca474ac50f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 451, 3725.5, 1749.6),
('fb921a99-6a3b-5b6f-8c70-4819f492978b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 452, 3722.7, 1750.6),
('e8c307d6-0eee-5798-b8cc-88f632f1327e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 453, 3719.8, 1751.5),
('77978af7-3b3e-50bb-a58c-04ae8c7e9acb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 454, 3717.0, 1752.4),
('ee890646-35e0-5175-b6b9-19bffb491793', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 455, 3714.1, 1753.4),
('aca86f42-14e7-529f-91e5-29e279366c12', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 456, 3711.3, 1754.3),
('b2a881f4-9fc0-5370-a8c8-0eddd271c9c9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 457, 3708.4, 1755.2),
('047dc522-54fe-572d-9b6f-38accc0495e5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 458, 3705.6, 1756.1),
('c84b1908-f09d-5e3c-8a44-a93da4ce0c1b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 459, 3702.7, 1757.0),
('12c64ea1-e1ad-506f-8115-6744fc2f5b85', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 460, 3699.8, 1757.9),
('b401a23d-5f2f-5033-9822-2487a4d4594e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 461, 3697.0, 1758.8),
('9ad7dc22-bcf1-5b8e-87a5-bcbf27fb43eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 462, 3694.1, 1759.7),
('ad004422-7076-5ba3-b09b-e7e094b5c4ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 463, 3691.2, 1760.6),
('8e5b84ee-03e7-5366-9a65-283127993959', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 464, 3688.4, 1761.5),
('e55ebd59-51e6-58f1-b104-f1fd5f992b8a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 465, 3685.5, 1762.4),
('ce4a91a2-dabf-54fa-a0f7-53095a8b87e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 466, 3682.6, 1763.2),
('13e21a9c-b280-5a0d-b155-303fcbca16e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 467, 3679.8, 1764.1),
('f9580ed3-9758-588f-836f-a64e83da6392', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 468, 3676.9, 1764.9),
('b363d3b0-b8ae-52c4-96c3-3e18e6b203d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 469, 3674.0, 1765.8),
('5dc636ef-e59e-5890-9aa4-a591d75b262d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 470, 3671.1, 1766.6),
('0d7d72aa-bb0b-5f1e-89ca-00c6a2b676eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 471, 3668.2, 1767.5),
('17508aff-9b6a-5c8b-b839-8b0db7b208a9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 472, 3665.4, 1768.3),
('27abcfbb-7f47-5cda-9cc6-ac043f92ba51', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 473, 3662.5, 1769.1),
('0575abbe-0d80-5899-bfd0-bcec393168cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 474, 3659.6, 1770.0),
('17b529bc-f9b6-5d50-af22-413ce50de1f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 475, 3656.7, 1770.8),
('ec6a8e87-aec7-5d21-98e7-bc0cbd9a0403', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 476, 3653.8, 1771.6),
('a25bf428-4257-5473-b154-a018b143b4c2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 477, 3650.9, 1772.4),
('ad7243de-eaf4-5a57-b3c2-3f9cec1ccf4d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 478, 3648.1, 1773.2),
('1917b980-5bfc-5515-a0e2-4be788fbb776', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 479, 3645.2, 1774.0),
('e861fb1c-32f0-5dd1-bf30-f43bcb295121', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 480, 3642.3, 1774.8),
('20140d2c-4d56-59cd-9dab-e7ac7217cf6f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 481, 3639.4, 1775.6),
('eefb1092-d9f4-5107-9fdb-01d8bab1477e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 482, 3636.5, 1776.4),
('21d3884e-8968-545e-9448-354978a39fde', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 483, 3633.6, 1777.2),
('4225d5d7-201e-59f0-a4dd-4e0c29a41746', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 484, 3630.7, 1778.0),
('2a63f056-bc7c-582a-8531-b018212a4682', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 485, 3627.8, 1778.8),
('e68c363c-64e6-536d-8716-38a29fe07881', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 486, 3624.9, 1779.5),
('e514aa50-da96-5594-9ec2-c6c5077bacf8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 487, 3622.0, 1780.3),
('63920795-c62f-5c9a-bf4c-7e95672a3cad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 488, 3619.1, 1781.1),
('19beab8e-43b6-51cc-a0e1-7e361ba0021d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 489, 3616.2, 1781.8),
('f8e870d9-9e12-588e-8f0b-6aadf88891aa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 490, 3613.3, 1782.6),
('c0a4a6dd-c595-5791-8111-85f41181c0d8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 491, 3610.4, 1783.3),
('bd93482a-f996-5ee0-bc2e-04d2712607ed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 492, 3607.5, 1784.1),
('866ebe3c-a202-5a4b-9b5a-e88d5eab9627', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 493, 3604.6, 1784.8),
('7c06e487-7206-55d1-86e3-fb5a843ac227', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 494, 3601.7, 1785.5),
('19025e31-ae1b-5923-bdb1-42011ac35bd3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 495, 3598.7, 1786.2),
('a217b5c9-eca5-5db7-b73f-f4ca728831b8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 496, 3595.8, 1787.0),
('fc238603-ede4-55ac-b2d5-1e371b3a3a95', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 497, 3592.9, 1787.7),
('2ddaf304-aabc-5ab7-ad9d-b4b61d8b2823', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 498, 3590.0, 1788.4),
('3362fbb1-184f-5227-8beb-58c2abf80135', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 499, 3587.1, 1789.1),
('3477d073-e649-5bad-8331-31388f28000e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 500, 3584.2, 1789.7),
('3c8c8b60-997c-5664-b918-50c097efb156', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 501, 3581.2, 1790.3),
('5c23170c-2243-5ed7-ad66-91a5e005c9ab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 502, 3578.3, 1790.9),
('1311d744-0cc9-5782-be8c-47d072d0e4a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 503, 3575.3, 1791.2),
('4af2b25d-bf98-5f30-bf19-561569698206', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 504, 3572.3, 1791.5),
('53c8df82-c2a4-50d9-bd91-586cfe5d6053', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 505, 3569.3, 1791.6),
('59560af1-7268-50e2-8b25-25476f5c1ee3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 506, 3566.3, 1791.6),
('0fd5c9cd-c44b-5c00-a734-b99bc88295fa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 507, 3563.3, 1791.5),
('1840c56e-0cab-588e-9950-b4336b3cb7cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 508, 3560.3, 1791.3),
('7b1f533a-96e3-52b4-a998-8e496efde959', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 509, 3557.3, 1790.9),
('519ba267-1a26-50c4-b14e-e33d566d3661', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 510, 3554.4, 1790.5),
('e6546c5f-da36-5926-8db6-5273196ad8b0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 511, 3551.4, 1790.0),
('595069e0-6be2-5ea2-b6b5-e495e87d8803', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 512, 3548.5, 1789.4),
('eab015cb-fb2e-56ed-9ecc-cd6adc6c6e01', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 513, 3545.5, 1788.8),
('0a920391-f995-5c42-88af-c2bf3f75ba07', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 514, 3542.6, 1788.0),
('48dd51bd-42bb-5f9b-a28a-8a996b682a8e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 515, 3539.7, 1787.2),
('5ac57462-0f29-5b19-b328-e4ac0d0280af', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 516, 3536.9, 1786.4),
('9956ab49-8e27-5f94-b421-757eeb5969c2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 517, 3534.0, 1785.5),
('36327cf8-1881-5418-8e13-f41e0ceecd41', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 518, 3531.1, 1784.6),
('ca1b1cb5-4dbb-5690-91df-d16531a77456', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 519, 3528.3, 1783.6),
('9c12de94-1a9f-56e9-8814-4b0721f12c8e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 520, 3525.4, 1782.8),
('a7ed833d-7c61-5675-9e43-2e5881872548', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 521, 3524.7, 1784.1),
('8af48f62-b4af-528e-ba34-698645bf2484', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 522, 3526.8, 1786.3),
('9aa44876-d237-57b3-b599-109b9ffd1da9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 523, 3529.1, 1788.3),
('ef6929c3-70fb-52f3-9bd3-2aeb4344b2cf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 524, 3531.3, 1790.3),
('b66e72f2-66e6-56f6-836b-52a1414a993b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 525, 3533.6, 1792.2),
('f82e0dd5-d609-5d38-8a54-403d59bc9271', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 526, 3536.0, 1794.1),
('49826f04-c41a-559a-af67-0679f47ffecd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 527, 3538.3, 1795.9),
('b4287478-a352-55f6-896a-511c7dbf1eca', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 528, 3540.7, 1797.7),
('1cece29e-9c0e-5f6b-acb7-d656128fc9fc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 529, 3543.1, 1799.5),
('b0639363-a598-5780-83ce-811173e1fd28', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 530, 3545.5, 1801.3),
('39d56a53-819d-53ef-8f7a-14a598f7a1a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 531, 3547.9, 1803.1),
('b9bd1b36-f101-54f3-8a34-433991777026', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 532, 3550.4, 1804.8),
('c011281e-c5cc-56e8-bb42-1f128afaed2a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 533, 3552.8, 1806.6),
('529360fd-e306-5cc2-9edb-9f7b653e42a1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 534, 3555.3, 1808.3),
('d3621665-7120-599d-b453-d358615caf60', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 535, 3557.8, 1810.0),
('cdd28cec-240c-5e71-a639-c46f87f73f4a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 536, 3560.2, 1811.7),
('9fc5379e-335c-5f5b-b5d3-46c4cee83cc2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 537, 3562.7, 1813.4),
('33f74438-8c71-582d-a43f-32aac22f327c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 538, 3565.2, 1815.1),
('551c2345-df31-56f2-96ad-a3fba30f9fda', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 539, 3567.6, 1816.8),
('9876f395-f022-5d14-80f3-108174377eea', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 540, 3570.1, 1818.5),
('8139881f-7cd5-5524-bb53-db2d072389c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 541, 3572.6, 1820.1),
('185e15d4-43ee-54da-b9f5-4766c5e698da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 542, 3575.1, 1821.8),
('377f8663-e5e8-5fca-b727-08a28a5ffa5e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 543, 3577.6, 1823.5),
('d32ccfbb-93ed-558c-bef5-9a6911de958c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 544, 3580.1, 1825.1),
('875a7299-03ff-598a-9f56-94f863a2a98a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 545, 3582.6, 1826.8),
('9fcb95a0-eba2-5e48-bfe3-c688fc8d49c1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 546, 3585.1, 1828.4),
('39b84f84-e2c2-5598-a323-bb189c6f0b4e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 547, 3587.6, 1830.1),
('48a540f0-b112-5647-82b8-49db1c2f572f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 548, 3590.2, 1831.7),
('1fa1e591-2d5c-56cf-9a49-e1065fb49f3f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 549, 3592.7, 1833.3),
('09969ff8-2294-5806-8a01-be51e582df28', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 550, 3595.2, 1835.0),
('45386e99-b007-590f-bf2a-aca820a8b6dd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 551, 3597.7, 1836.6),
('4b974af9-6424-5029-bd77-722f8779db89', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 552, 3600.2, 1838.2),
('ab174512-623f-5ded-96c9-c353b46b0c4e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 553, 3602.8, 1839.8),
('b06b35fc-7b4d-580c-b264-b69f804bbf02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 554, 3605.3, 1841.5),
('afc3f59f-01b5-55ef-9960-3d501da28189', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 555, 3607.8, 1843.1),
('e04bd27b-c684-5926-aa4a-f1c7229cf3ab', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 556, 3610.3, 1844.7),
('6af4b93f-c72f-58a3-ac98-28c0fbb470de', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 557, 3612.9, 1846.3),
('f35b294b-e75d-5e15-9bb5-e282b4411299', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 558, 3615.4, 1847.9),
('feb4d4c7-c759-5fa3-9108-a3547fbf8d06', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 559, 3617.9, 1849.5),
('5e0d632a-beae-5c75-8541-4919b3abf8bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 560, 3620.5, 1851.1),
('ba822b62-ae85-5275-b39f-31681b1d69e7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 561, 3623.0, 1852.7),
('237ac79f-24fd-5cdb-b32c-dea0085be798', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 562, 3625.6, 1854.3),
('bbec1e43-2432-578f-a198-15c2ddac5476', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 563, 3628.1, 1855.9),
('10d60730-ff16-5989-ae8b-e0f46bf37133', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 564, 3630.7, 1857.4),
('7babe73b-ae11-5c81-8287-d33bbd76b42c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 565, 3633.2, 1859.0),
('06c55411-2441-5b25-b88e-ee83ef667157', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 566, 3635.8, 1860.6),
('c527436e-1dbe-5911-8c3c-7f3d0b05490c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 567, 3638.3, 1862.2),
('d35f88bf-be55-50c6-886e-865a1dd1bd27', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 568, 3640.9, 1863.8),
('125ec783-afdf-5380-95bf-428ee0b39cd7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 569, 3643.4, 1865.3),
('070dbc7d-1299-5685-86a9-91017d2f4a0a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 570, 3646.0, 1866.9),
('5ce97e63-e920-5c72-bcb1-86f5775fedf9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 571, 3648.5, 1868.5),
('cb65b673-5d3f-5ea6-8ffc-e8f769c65a47', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 572, 3651.1, 1870.0),
('f3f27afb-d8ce-59b1-8dc0-2084a02de4e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 573, 3653.7, 1871.6),
('dcd02c20-f796-5dcc-a6d7-b31129a8cf81', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 574, 3656.2, 1873.1),
('c214ebe6-f07d-5b7f-a706-5ca9d4e94d98', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 575, 3658.8, 1874.7),
('c3b9ff99-2a51-5a3c-95a5-e28a7fecba47', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 576, 3661.4, 1876.2),
('149922b7-e94b-51c6-b3ed-927037cfc18e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 577, 3663.9, 1877.8),
('17e68fdb-f0a1-5769-b808-763a6b88aa96', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 578, 3666.5, 1879.3),
('539a643a-0625-5c3d-a696-12d23add5f69', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 579, 3669.1, 1880.9),
('357b86ad-d94c-53b4-bb50-f6d0d2bfb5f4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 580, 3671.7, 1882.4),
('8d389c4b-9f22-5013-b31a-3df044362da4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 581, 3674.2, 1884.0),
('4472a078-0640-5514-b6d1-d17ab6c1c93b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 582, 3676.8, 1885.5),
('a274ec46-5eff-5b42-b612-0e4127369252', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 583, 3679.4, 1887.0),
('d68af63e-04dd-52b8-b383-7550e7caa34b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 584, 3682.0, 1888.5),
('a6e4bb6a-e8f1-55d6-b528-a1dd0e3a5a9f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 585, 3684.6, 1890.1),
('67ce2cf3-129b-5e5e-86d6-f141290e8091', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 586, 3687.2, 1891.6),
('2a461c07-e427-5599-8de5-19791d6a95b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 587, 3689.7, 1893.1),
('87f8a4f7-5ab4-5b4b-8dd1-efb023c1fe76', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 588, 3692.3, 1894.6),
('0b32ddfe-29b1-5a95-bc6e-0e452b975686', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 589, 3694.9, 1896.1),
('ed6e9fe2-f16d-5543-bb18-ccfcb5de5aa2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 590, 3697.5, 1897.6),
('4a59d46d-5c10-5ec3-a3f0-ef176f68d06b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 591, 3700.1, 1899.1),
('5699de5d-aeed-5cc5-8967-eb6d97a128d5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 592, 3702.7, 1900.6),
('f35e84a6-b255-565b-92db-db0a57a4ac3d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 593, 3705.3, 1902.1),
('b4cf35a7-1db4-5c2b-9555-2cc48b4ba2eb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 594, 3707.9, 1903.6),
('134c5000-12dd-55ce-a7b4-1d91b60876b3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 595, 3710.5, 1905.1),
('4ef239b6-4109-5a46-a47a-7291392f58d5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 596, 3713.1, 1906.6),
('e8afa9cc-5ede-5b4b-889e-4abca05c8618', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 597, 3715.8, 1908.0),
('2daba38e-df6c-599d-88bc-ae052966ff50', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 598, 3718.4, 1909.5),
('b551072a-b070-5920-94ad-b5a3c05b4103', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 599, 3721.0, 1911.0),
('768f99d7-55ec-5400-bd50-680424e26542', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 600, 3723.6, 1912.4),
('14fc80ea-2f8c-514a-8c41-11cfa6bff737', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 601, 3726.2, 1913.9),
('56483e5d-e00b-523e-8ad0-be445c4c0fd8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 602, 3728.9, 1915.3),
('92df2152-8a78-5f0c-b643-c22d77c46f9c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 603, 3731.5, 1916.8),
('964913fa-cf3a-5f08-9621-6d08cd51f35f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 604, 3734.1, 1918.2),
('1536dbe7-5ddf-5b2f-a6a4-30b056a52de0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 605, 3736.8, 1919.6),
('29cdf079-63ec-59ac-82ff-3c9ec05f77b7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 606, 3739.4, 1921.0),
('533495fc-dfe6-5835-9a96-7e93b11e9fcf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 607, 3742.1, 1922.4),
('10b71854-9beb-5ef6-bba6-7f008c5606f0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 608, 3744.7, 1923.8),
('d75b4900-8013-5d44-947d-9a09f4d8588e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 609, 3747.4, 1925.2),
('891be652-d72c-5fe8-87de-a1e91d2605a7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 610, 3750.0, 1926.6),
('112f41d9-48c2-5852-b1c1-498e984f910b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 611, 3752.7, 1928.0),
('166180dc-721e-5006-aed6-725fe96a3e67', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 612, 3755.4, 1929.4),
('69617a95-f9d2-52cc-a185-a242b264fae6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 613, 3758.0, 1930.8),
('68fb5ffc-3809-57bd-800a-048d08bcec35', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 614, 3760.7, 1932.1),
('d8a537f0-81a9-5845-adab-f4fb4654a9e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 615, 3763.4, 1933.5),
('9c5e83ab-0020-5540-8dfc-ac06180862ed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 616, 3766.1, 1934.8),
('6a3ae021-58f4-5b54-ad2d-96f81ab0145a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 617, 3768.7, 1936.2),
('750b47c7-83a3-570b-a6fe-d213ba058d49', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 618, 3771.4, 1937.5),
('3261e3a6-7fde-5200-9266-b83c54ee7ffe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 619, 3774.1, 1938.9),
('7495ec17-36df-5a30-b54a-ff1e751e7839', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 620, 3776.8, 1940.2),
('25513beb-1e6a-5b2e-8f61-16436b7e2d0f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 621, 3779.5, 1941.5),
('0747dc58-63f0-5703-bb5f-cbbfc31cb078', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 622, 3782.2, 1942.9),
('209c7e91-cb68-5497-8173-d84c9e816c3c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 623, 3784.9, 1944.2),
('b1250add-2d82-52a2-b618-72378ede9add', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 624, 3787.5, 1945.5),
('506a54df-9032-529b-9514-b33f4e1db2c0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 625, 3790.2, 1946.8),
('b570286d-7f79-5142-bd65-8e16e9f4691f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 626, 3792.9, 1948.1),
('92fb8d00-b2d6-59e6-92f8-0da70239f293', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 627, 3795.6, 1949.5),
('ac25ed88-207a-506a-8320-ef0c991f316b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 628, 3798.3, 1950.8),
('c9f49689-d842-5959-b462-5257a1d12717', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 629, 3801.0, 1952.1),
('3699478c-3aae-52e5-a641-fe469ec9c82e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 630, 3803.7, 1953.4),
('1bdeee0a-21ac-573b-9444-5a8c9c0fb555', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 631, 3806.4, 1954.7),
('aac5ee10-f856-5ac1-8808-5428a75785ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 632, 3809.1, 1956.0),
('0cb066ec-7577-58d5-85c0-a97bbd1c5965', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 633, 3811.9, 1957.3),
('35967497-256b-537e-8e13-ba631c12814d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 634, 3814.6, 1958.6),
('7e3c7dcd-066d-5120-ac59-68fda3c0878c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 635, 3817.3, 1959.9),
('0967d142-ebd5-59fd-a9a0-5ef1e0c1e386', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 636, 3820.0, 1961.2),
('6081eb55-0435-5be5-a1aa-9585a14a3177', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 637, 3822.7, 1962.4),
('589f977b-5340-5ec6-acf1-3b663ce37660', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 638, 3825.4, 1963.7),
('221b8797-639b-54b3-86ea-e0325be95be9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 639, 3828.1, 1965.0),
('83173011-4b98-5b58-9fb3-ff7a7b946c2b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 640, 3830.8, 1966.3),
('b2477821-629e-520e-8029-39562382cf5d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 641, 3833.5, 1967.6),
('57a742d4-a942-5bb0-b186-7921368e5c3a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 642, 3836.2, 1968.9),
('d85270b0-b503-5684-9fd0-853df9832cd1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 643, 3838.9, 1970.2),
('bac798d9-d380-5eaf-9861-c19ccb9116ff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 644, 3841.6, 1971.5),
('8a1ac7d6-cee6-5d57-a760-424bd7d669c6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 645, 3844.4, 1972.8),
('4ef440ff-9d9e-5031-9d50-c06be45e26cd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 646, 3847.1, 1974.0),
('43595c8b-5f20-5949-9488-55cb245e3481', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 647, 3849.8, 1975.3),
('0da9cda3-d136-57b9-8eab-060cfe4cb318', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 648, 3852.5, 1976.6),
('982caf76-4792-52ba-a739-e34d30482aef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 649, 3855.2, 1977.9),
('98db5126-ec7b-5296-9a36-87e219822923', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 650, 3857.9, 1979.2),
('7c61392c-8eec-51e0-b419-d9d00c52fae0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 651, 3860.6, 1980.5),
('075feecf-3b88-59e1-81d0-1deea76c4960', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 652, 3863.3, 1981.8),
('e59fa210-c19e-5001-8269-007d825b5ed5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 653, 3866.0, 1983.1),
('7ad97620-763c-5cb8-b02f-9ef9ea635428', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 654, 3868.7, 1984.4),
('e4d9b01e-a816-5b22-bc9a-689ce7ce6c10', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 655, 3871.4, 1985.7),
('974cb28f-f895-51f6-8a09-1f710553b6da', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 656, 3874.1, 1987.0),
('a3e8a6b1-fe4a-53a5-a171-62b269700fcc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 657, 3876.8, 1988.2),
('ea31edb4-c003-54af-abb5-44f3e004b945', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 658, 3879.6, 1989.5),
('e74eec66-9479-5a15-9bae-d9dbfa8a8339', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 659, 3882.3, 1990.9),
('151ca111-590b-53d3-bda7-4bd7bba122c0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 660, 3885.0, 1992.2),
('62c1be6f-0033-504b-8a50-5df720112f24', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 661, 3887.7, 1993.5),
('b3abe402-ba6a-539b-8788-d19742fdd06a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 662, 3890.4, 1994.8),
('20eb9c0d-d9c5-5152-822f-11510517ff3b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 663, 3893.1, 1996.1),
('c0b79058-71c2-5b63-9995-d0d638520426', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 664, 3895.8, 1997.4),
('1a721146-0079-5ae1-9033-561a7ec45439', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 665, 3898.5, 1998.7),
('bb979e37-6587-58c9-933b-4c6287807908', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 666, 3901.1, 2000.0),
('694fc6fa-ad41-502a-a83b-67f0794ffcb5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 667, 3903.8, 2001.3),
('33ac28d5-2dc5-5d4a-8799-7c7518f9bb9e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 668, 3906.5, 2002.7),
('f100da34-8494-5150-8b71-863ce8d39287', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 669, 3909.2, 2004.0),
('79101a43-5c92-515c-b67d-44a69b6bf176', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 670, 3911.9, 2005.3),
('fc36cece-3d26-5485-8c63-01d377d37760', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 671, 3914.6, 2006.7),
('752f0011-cd12-5815-ac27-a7930004e337', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 672, 3917.3, 2008.0),
('6d316cbe-4397-5e71-ba92-f98618a9ea7a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 673, 3920.0, 2009.3),
('7cdc303c-f5e9-5129-8772-120dbf6e1317', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 674, 3922.6, 2010.7),
('05736790-1079-53fc-b71c-0d75bd3a3eb2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 675, 3925.3, 2012.0),
('b4320cbc-51e6-593b-b637-6b22059c0e64', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 676, 3928.0, 2013.4),
('e4a0a7bb-51cd-5bda-9d0a-c02dda3b1e7a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 677, 3930.7, 2014.7),
('b632f8a5-e3d1-5c9a-b165-25e622a3b479', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 678, 3933.4, 2016.1),
('826ae06f-418f-56ef-aa39-736c535eacce', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 679, 3936.0, 2017.5),
('1ba24bc6-2156-5616-802e-36f2de24f82b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 680, 3938.7, 2018.8),
('392f30f9-29fb-5f56-9a10-6636c70ec3a8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 681, 3941.4, 2020.2),
('1f756de3-c9b1-5263-8d6d-5355472b1d8d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 682, 3944.0, 2021.6),
('88038b24-be16-5591-9aac-e45a22dcf55b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 683, 3946.7, 2023.0),
('1af0cb10-7876-541c-ba5c-dfe4ad4365e7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 684, 3949.4, 2024.3),
('68d1caea-1a4b-58c9-90cf-45f186abd59e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 685, 3952.0, 2025.7),
('ce07042e-4e9c-5ccd-af9e-d763e1ecccf8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 686, 3954.7, 2027.1),
('ae278fb1-12d3-50c8-90f2-b552c0f2c504', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 687, 3957.3, 2028.5),
('41e60a07-0776-501c-94f4-441908b83de0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 688, 3960.0, 2029.9),
('704d23d9-a964-5caa-a654-762cbe693c6c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 689, 3962.6, 2031.3),
('cfa0f897-3035-57b0-977c-016cd8d60a55', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 690, 3965.3, 2032.8),
('7936ac9b-a414-5e07-9946-5ed5160e5ad5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 691, 3967.9, 2034.2),
('5046353a-474f-585c-b2ec-642a41f6dfcc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 692, 3970.6, 2035.6),
('ced45049-a8ef-5d1d-ae9a-198d93f54a87', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 693, 3973.2, 2037.0),
('05b7773a-1be2-5519-9fde-06d6e06c9534', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 694, 3975.8, 2038.4),
('5dd00fe6-2676-56dd-8fe3-f943dd45a7a7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 695, 3978.5, 2039.9),
('f615a2da-f64d-5092-8adf-d9c595b4e9bc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 696, 3981.1, 2041.3),
('2e76b22f-c9b8-58c5-86e6-43e75061112b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 697, 3983.7, 2042.7),
('672798a4-9f0c-5a79-9f12-0f571b2b37e3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 698, 3986.4, 2044.2),
('f3c4bdae-9803-5766-be1d-9821711bbfcc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 699, 3989.0, 2045.6),
('8e6b0fcc-8abb-5e23-bde9-85ba84c751df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 700, 3991.6, 2047.1),
('560d05bd-ea12-56c9-a631-b9d226cfc90d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 701, 3994.3, 2048.5),
('97cb8ce0-5b20-5f72-a40d-5d470f2adcb8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 702, 3996.9, 2050.0),
('63f73052-4883-5554-a216-85458bd0b4cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 703, 3999.5, 2051.4),
('f9e1d513-e439-541e-b312-88425a29330c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 704, 4002.1, 2052.9),
('7062cd66-ed48-58a1-b852-9e4638cd53f7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 705, 4004.8, 2054.3),
('9f00c9e4-5935-58c1-ac86-78449b52353d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 706, 4007.4, 2055.8),
('34a59bc4-4b54-5f68-a44a-f515d1db5dad', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 707, 4010.0, 2057.3),
('084b26a6-4285-5983-a512-1c4291050660', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 708, 4012.6, 2058.7),
('d23bfb04-ac81-5e41-bb75-2a57407d3bd5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 709, 4015.2, 2060.2),
('cc594cc6-5bdf-5ea3-8aee-042d96ac0f6c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 710, 4017.8, 2061.7),
('84bb65b0-ce08-567d-880c-e1c092bdaf07', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 711, 4020.5, 2063.1),
('588b61d8-f5cc-5835-82eb-1868e5316a58', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 712, 4023.1, 2064.6),
('ba5b76a5-9069-52af-baa6-ad2b14ff979a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 713, 4025.7, 2066.1),
('3156e5a0-b261-57e6-aed6-c623ea697fd0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 714, 4028.3, 2067.6),
('de546fad-6b85-540b-88e9-3921b6353841', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 715, 4030.9, 2069.0),
('364cb1db-6b5b-5c61-b2c9-dd5c25d28f5f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 716, 4033.5, 2070.5),
('ae93f8e9-cf72-5997-acfc-cb2ecff9c9ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 717, 4036.1, 2072.0),
('06baa4bd-3260-5abe-9919-a3434927d3a8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 718, 4038.7, 2073.5),
('c101de96-d3df-537b-a9ea-94eedf0cc944', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 719, 4041.3, 2075.0),
('9fdc463e-775a-5074-aa96-8801164b4472', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 720, 4043.9, 2076.5),
('b789282b-8f3f-51be-baa6-cff5e6f889f8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 721, 4046.5, 2078.0),
('98bfe6bc-3591-57f1-99d7-7afdbc762e06', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 722, 4049.2, 2079.4),
('d390d5e5-899a-5708-818a-f786a95e2f34', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 723, 4051.8, 2080.9),
('a1236806-fcf1-53ae-829d-2faeeebd9165', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 724, 4054.4, 2082.4),
('7f67cedc-5d18-5c7d-9c13-055ef8d28c2d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 725, 4057.0, 2083.9),
('c65e0407-f3c8-5c5f-a235-f12a3b7f3449', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 726, 4059.6, 2085.4),
('17213500-eeeb-59e3-a420-520a31218dfc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 727, 4062.2, 2086.9),
('067d4706-c39d-50f8-b79b-3e5df362c1b6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 728, 4064.8, 2088.4),
('c44970c8-dcb2-54e6-bacf-376315cc4bf1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 729, 4067.4, 2089.9),
('057913f9-35ab-5e86-a3e9-5ae77d71293d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 730, 4070.0, 2091.4),
('5dd3fdd5-b836-52c1-8890-f13072d440d7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 731, 4072.6, 2092.9),
('3fb0927d-3a3e-5004-88c5-ce80f09afe40', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 732, 4075.2, 2094.4),
('47635286-8f9c-5101-9ff9-556c6ca4089a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 733, 4077.8, 2095.9),
('f0401a8e-b7cc-599c-a2f8-15fb602d00fb', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 734, 4080.4, 2097.4),
('8dd39f3e-db0b-5ffd-a956-92647650e4c7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 735, 4083.0, 2098.9),
('112db772-2578-54a1-b4a6-1f6b05e60aed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 736, 4085.6, 2100.4),
('7f6d5726-d8fc-5914-9d29-e2d2822c9a7d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 737, 4088.2, 2101.9),
('05246ac4-2d8c-5387-a8ed-676f91cb0d32', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 738, 4090.8, 2103.4),
('744d8c92-f159-563a-9fac-5f37f6b8c23a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 739, 4093.4, 2104.9),
('7a6bd20a-d3ef-5d5a-98ce-3b92d00b8cfd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 740, 4096.0, 2106.4),
('2077537f-6b96-58f3-8cf6-861928f811f4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 741, 4098.6, 2107.9),
('9d57b516-627e-5a41-9641-b2c71b578852', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 742, 4101.2, 2109.4),
('4a920172-90d8-51a0-ab3e-15afe4ff89b7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 743, 4103.8, 2110.9),
('e831c183-4e41-5d40-96d1-c068f4929e94', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 744, 4106.3, 2112.4),
('a06414d6-a552-59fb-afa4-5190fe4f83ed', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 745, 4108.9, 2113.9),
('c1273d7b-e266-57df-8b7a-b66e320af2bf', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 746, 4111.5, 2115.4),
('9cc2e7be-c290-5c82-94a7-8f625ab04842', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 747, 4114.1, 2116.9),
('ec80d1f2-ab2b-5090-a8a5-dd1e805ccf51', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 748, 4116.7, 2118.4),
('a0185046-0675-5f66-9bdf-22952b25e125', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 749, 4119.3, 2119.9),
('c112fc73-410b-5898-b342-88e3544c167d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 750, 4121.9, 2121.4),
('4e1b6cdd-631d-50e7-a316-9cd7f88b3bd7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 751, 4124.5, 2122.9),
('f76f9633-dfa8-5ffe-afc9-9a0aca16acf2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 752, 4127.1, 2124.3),
('5b0c096c-0f0d-5b9a-9a83-639a0e990cae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 753, 4129.7, 2125.8),
('ae20f6fd-a560-5ecc-9c19-f300ce20c3d6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 754, 4132.4, 2127.3),
('4c134654-161f-5aac-b5a7-405db3885695', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 755, 4135.0, 2128.8),
('33e0a73d-e729-592a-b600-bdb72df7373a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 756, 4137.6, 2130.3),
('a70facdc-e440-5c50-922c-04485c47c8ea', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 757, 4140.2, 2131.8),
('26526638-1368-5c89-b66c-f695eba9f4c9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 758, 4142.8, 2133.3),
('71e1b452-b224-5ba8-9beb-ae1f5d7ef65c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 759, 4145.4, 2134.8),
('5ea798d7-86f7-5f79-8e0d-3e52c47d1953', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 760, 4148.0, 2136.3),
('a2ace09e-a835-599e-bba3-40bf74a21434', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 761, 4150.6, 2137.8),
('5432284f-3844-570c-a102-62ae86cf8a22', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 762, 4153.2, 2139.3),
('d96a2d86-f235-5aaf-966d-cd7cceb24529', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 763, 4155.8, 2140.7),
('c74e0d9a-7139-5087-8cb2-aaae64450a05', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 764, 4158.4, 2142.2),
('9d45aaa7-acdc-5554-9415-f8ac108f694f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 765, 4161.0, 2143.7),
('98befc13-161a-5a59-a762-a4502b84b4e7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 766, 4163.6, 2145.2),
('0bf586e4-369b-532c-91d6-942c372eeab0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 767, 4166.2, 2146.7),
('75f3a2ed-45e6-574e-a007-5cbb6fae96d5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 768, 4168.8, 2148.2),
('94819757-f3ed-5d1a-b444-f30430e4088e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 769, 4171.4, 2149.6),
('2f870e9b-778a-5f76-b8ec-72942c528fa0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 770, 4174.1, 2151.1),
('6f694317-305b-59e1-847d-9a8c6d326c7c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 771, 4176.7, 2152.6),
('f4f956c0-d79a-591c-b2e2-87fd1f9f71e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 772, 4179.3, 2154.1),
('ea7bd9e0-f29a-5a9a-aab5-d54697a7cf36', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 773, 4181.9, 2155.5),
('ba5f91fd-d67e-594c-a1a3-084f14ec7db6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 774, 4184.5, 2157.0),
('76a594e2-7a9a-53fc-b0c4-f21fbb2cbaf6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 775, 4187.1, 2158.5),
('60193db7-5dbf-52dc-ae3d-eebeafd55b82', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 776, 4189.7, 2159.9),
('b407f131-ab30-56c7-b421-5ac5b5f5bc1f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 777, 4192.4, 2161.4),
('e061b675-e0c1-5707-88a2-c852414e4e31', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 778, 4195.0, 2162.9),
('91aff268-369e-568b-b6e1-084be95906a4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 779, 4197.6, 2164.3),
('005c57c9-8d33-5dfd-8b6a-aec2ecbf00b9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 780, 4200.2, 2165.8),
('2d2fc07e-4570-5d7d-b92c-0e460d1b389d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 781, 4202.8, 2167.2),
('3d4f97ec-ec0e-5be4-b29c-e35b6eb376a1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 782, 4205.5, 2168.7),
('bdfddcff-c3bc-538c-a8b7-eb99619ec6d0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 783, 4208.1, 2170.1),
('41e0927d-d338-569e-909e-c69b531d2970', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 784, 4210.7, 2171.6),
('6281df7a-07cf-5c52-a386-3722ab45dadc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 785, 4213.3, 2173.1),
('31e51e3f-c9e3-5bbb-9f0f-54bdb9999d2b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 786, 4216.0, 2174.5),
('cbe48fc9-2ee1-5915-b4f0-b220c7d92577', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 787, 4218.6, 2175.9),
('3a264902-4a94-5da0-a25b-9b1f13894d0d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 788, 4221.2, 2177.4),
('c4504fe7-025f-5c67-8205-786dc5828737', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 789, 4223.9, 2178.8),
('4945ee60-120c-5811-9f5d-298bbc5a22ca', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 790, 4226.5, 2180.3),
('28ba36ee-607d-5df9-a13d-3b70f425b7d2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 791, 4229.1, 2181.7),
('48d96a5d-492f-5051-96d2-edb4e7e80680', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 792, 4231.8, 2183.1),
('ff57d612-4e23-56ce-b0f7-524616785681', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 793, 4234.4, 2184.6),
('6203c760-77ff-5696-ba33-fd1ec1d8d652', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 794, 4237.0, 2186.0),
('b291d53c-e769-5a7c-9a2f-07a1148ac822', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 795, 4239.7, 2187.4),
('88d0ff06-3e10-53f0-81b4-8dc6dcd69179', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 796, 4242.3, 2188.9),
('25b454a8-85b5-573e-aa56-b0203db6a130', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 797, 4244.9, 2190.3),
('b8ee0ba9-5017-5d1c-9fc0-7b86a2690cff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 798, 4247.6, 2191.7),
('8d91f321-d08d-54d6-bb39-8f8a4cb1c76b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 799, 4250.2, 2193.1),
('c68878d0-6786-56c0-ba93-742b12fc7c03', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 800, 4252.9, 2194.6),
('b8d18db8-ef48-5e1f-a006-7c4d2c98f7a6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 801, 4255.5, 2196.0),
('a6e1a974-6d2a-58a7-92be-0d3dc4766973', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 802, 4258.1, 2197.4),
('bdf7b2de-84ad-53f1-8aa6-3e5152067bb9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 803, 4260.8, 2198.8),
('39267fa4-d76c-53db-95f6-b8829ac5e24e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 804, 4263.4, 2200.2),
('4df97b46-8aca-5bdb-b08c-2fd6f8dfa7e9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 805, 4266.1, 2201.7),
('7bed504c-f6ef-58c1-a1be-4e514cef46a7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 806, 4268.7, 2203.1),
('1181a525-5431-5bcb-a17d-c81d21ea4596', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 807, 4271.4, 2204.5),
('3ca51f47-eeb4-54eb-9905-1044a113c7b3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 808, 4274.0, 2205.9),
('eeab9495-a714-596f-af7b-99622df64df2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 809, 4276.7, 2207.3),
('d1d12cce-c541-518d-af55-4647b1ba7088', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 810, 4279.3, 2208.7),
('ec7b8456-39e3-501c-be86-bb7fd9f6c032', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 811, 4282.0, 2210.1),
('e872416e-2885-5352-a5be-1e001d9e546b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 812, 4284.6, 2211.5),
('f76222d4-e52a-565d-abb7-e5deaa7437e2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 813, 4287.3, 2212.9),
('d6adf0bd-950a-5e56-8004-33fd53d26126', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 814, 4289.9, 2214.4),
('c372c2ac-984f-50c1-b594-249785c87d4e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 815, 4292.6, 2215.8),
('abbb323c-a63a-5b71-ad55-295ff0269c6a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 816, 4295.2, 2217.2),
('1b8fd3db-8a84-534b-bccd-63781321febd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 817, 4297.9, 2218.6),
('0c60eab9-b7c0-5bed-9f56-0f1020d607cc', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 818, 4300.5, 2220.0),
('e7a208cf-aecf-5b5b-a989-824ed3e5edea', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 819, 4303.2, 2221.4),
('ebf2cff0-3e31-5995-9f0b-0ede3d3ac7ff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 820, 4305.8, 2222.8),
('93fe72ad-35c6-51dc-a217-a79f86d0963e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 821, 4308.5, 2224.2),
('dac28851-72e8-56e7-9cc7-f9f8ab234aae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 822, 4311.1, 2225.6),
('6b594ae7-e1a4-5d0d-b252-a740d140b0ae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 823, 4313.8, 2227.0),
('2d7ee468-5a3c-57f2-b4ac-a07ebfe8c9bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 824, 4316.4, 2228.4),
('8b5a9a24-29c6-5ce1-ac07-dc0f067237df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 825, 4319.1, 2229.8),
('71a92505-4cb6-5f99-9629-403ca5913e9e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 826, 4321.7, 2231.2),
('7c429cb7-7bdf-5964-bf29-773d4a8ff2d8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 827, 4324.4, 2232.6),
('9d62afe3-a241-50b7-a692-2b01568c63e1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 828, 4327.0, 2234.0),
('11892555-4f5d-56bb-8681-c905c384f747', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 829, 4329.7, 2235.4),
('04874676-243d-5418-89db-7b6bea785307', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 830, 4332.3, 2236.8),
('6551d5d7-aa48-5331-b4e7-0a2945e0ef46', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 831, 4335.0, 2238.2),
('9cf2aab1-fdde-587d-b5cd-31c783b2c90b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 832, 4337.6, 2239.6),
('f791ddce-ab9f-553d-aa9e-18373e1cbda5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 833, 4340.3, 2241.0),
('0fe11143-e325-5710-9994-9f3af4acf6ec', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 834, 4343.0, 2242.4),
('c1ef019d-2ec8-53b6-a428-4656ba0547e2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 835, 4345.6, 2243.8),
('96c49700-ae75-5cde-af21-3667cc004099', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 836, 4348.3, 2245.2),
('8826ba04-a730-5b2d-b514-ce8fb0cfa876', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 837, 4350.9, 2246.6),
('2e51f984-b6ab-5e32-8b36-e9124d935253', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 838, 4353.6, 2248.0),
('9656081c-5ffb-5223-9c5f-466e1536081f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 839, 4356.2, 2249.4),
('49d26781-10e8-5c5d-9ba0-be719a2168e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 840, 4358.9, 2250.8),
('5adffd7a-92b9-5c2b-a455-fa727d00f3ef', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 841, 4361.5, 2252.2),
('562db99e-86d8-5f08-becc-13788daa7491', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 842, 4364.2, 2253.6),
('623e324c-cc1b-5597-8642-4ca009fd4a37', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 843, 4366.9, 2254.9),
('98eafe13-6b7c-5f88-93d9-f4cffb1fdf1a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 844, 4369.5, 2256.3),
('0710784d-d26c-52b5-9d5b-886ffec4959d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 845, 4372.2, 2257.7),
('8c14b66b-3da1-5877-9a5b-5e58f5bbb645', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 846, 4374.8, 2259.1),
('268c1015-a034-501e-bb07-c0dd1361871d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 847, 4377.5, 2260.5),
('e689e61d-7cf4-55a8-9e8d-63f1b223cd17', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 848, 4380.1, 2261.9),
('0aba9c0f-4e7e-522d-95fd-94ddbf1b7367', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 849, 4382.8, 2263.3),
('c597b5b2-8a89-5f4d-9a88-f5e96948ab46', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 850, 4385.5, 2264.7),
('43167bf0-179e-51a5-8173-e949dd35b242', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 851, 4388.1, 2266.1),
('4b26e36e-430e-5cea-92db-d70b0b4edb59', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 852, 4390.8, 2267.5),
('d6a82a38-f6ce-5cc0-a0c0-0d6044d201f5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 853, 4393.4, 2268.9),
('d927929b-8b65-588e-b8f6-3679c81a6aee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 854, 4396.1, 2270.3),
('73308c00-b71e-5cf3-83e4-bdfdcf2314ce', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 855, 4398.7, 2271.6),
('19ab9e10-0b7f-57cd-bbcc-7c35978d6fb2', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 856, 4401.4, 2273.0),
('e18440c2-80f1-5cd7-bd00-98798b8082e4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 857, 4404.1, 2274.4),
('d9ce46e5-baef-5350-8413-f9e9514214bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 858, 4406.7, 2275.8),
('04c39bcb-4156-5468-b4b2-4550727c40af', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 859, 4409.4, 2277.2),
('a306e18f-ffe9-58fa-995f-c3772b24559e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 860, 4412.0, 2278.6),
('54a13b68-ac14-5a46-a302-9cd867b07fb9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 861, 4414.7, 2280.0),
('7ce64c8f-641d-520b-adf3-3b42ee3222a0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 862, 4417.4, 2281.4),
('ffb8fa33-30f8-5c89-afd2-fa5fa6631718', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 863, 4420.0, 2282.8),
('a88af065-09aa-5bc4-9193-102ba5073bff', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 864, 4422.7, 2284.1),
('9fddf123-180d-5e9d-9446-766cd48b3b0f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 865, 4425.3, 2285.5),
('140a17a4-0a75-5b1e-b667-648c8dee0f68', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 866, 4428.0, 2286.9),
('cc5be69c-407f-5613-bcb3-7b1427e61ea5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 867, 4430.7, 2288.3),
('5140ce33-beb4-591e-9127-cd3aae0238bd', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 868, 4433.3, 2289.7),
('61a36a50-9977-56a5-b2e4-778d74040827', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 869, 4436.0, 2291.1),
('909b8a63-a6d6-5bdb-921d-818ffb8fa38b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 870, 4438.6, 2292.5),
('7df0e473-bc5c-5b07-b795-1fbe6dab0164', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 871, 4441.3, 2293.8),
('05353700-667b-52dd-8d7d-1a293253a323', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 872, 4444.0, 2295.2),
('7657433e-2639-5868-b181-bbd3e9a4844f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 873, 4446.6, 2296.6),
('c0894697-e182-51d0-b957-1e15aeaa4c46', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 874, 4449.3, 2298.0),
('519bc382-ca23-5269-8bbf-8f84bc5ff1ee', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 875, 4451.9, 2299.4),
('f32dcdaa-2174-5dd9-8019-18f93214fad6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 876, 4454.6, 2300.8),
('30dfa188-d8e2-5215-b7ca-34a458335910', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 877, 4457.3, 2302.2),
('a7e21c6b-86a9-5577-98fa-f57512c73cf7', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 878, 4459.9, 2303.5),
('fcda40e1-4ca9-5c59-b157-d887b4cb639f', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 879, 4462.6, 2304.9),
('1c939790-e5c0-593e-a551-6e098eab1b02', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 880, 4465.3, 2306.3),
('b0c4b052-0f78-5a49-abb1-bb5f172c6ca3', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 881, 4467.9, 2307.7),
('8d6e8194-8ed8-5aaa-af53-2f6d97aaee22', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 882, 4470.6, 2309.1),
('457e34eb-a900-5b72-bb4b-e694a9d5305e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 883, 4473.2, 2310.5),
('22650e25-3010-53c2-b0d7-c66bc4795d88', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 884, 4475.9, 2311.9),
('0ac2d63e-c934-5adf-bb23-0c2cfa9e312a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 885, 4478.6, 2313.2),
('e5757474-063b-5349-80d0-2a233cae3302', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 886, 4481.2, 2314.6),
('60dfbfa0-b520-5953-b1aa-40f3f2dac80a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 887, 4483.9, 2316.0),
('ad2bb382-a250-512a-b69a-c5a8dadb2776', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 888, 4486.5, 2317.4),
('9ec87a43-e54e-5269-994f-c1ccdef43cbe', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 889, 4489.2, 2318.8),
('ff07d77a-8df1-5850-abcc-b0a9ade31c49', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 890, 4491.9, 2320.2),
('c573bb85-5191-5776-81b7-ef20c9765113', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 891, 4494.5, 2321.5),
('fc033d5b-ee02-5c62-8131-2f9929fcba5c', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 892, 4497.2, 2322.9),
('1196995f-95ad-56a6-af12-d437d77a23b4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 893, 4499.9, 2324.3),
('1a3ae92d-9022-5999-8161-f92795c9a819', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 894, 4502.5, 2325.7),
('9581ce3b-91b7-5e01-b8ad-7f313822a72d', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 895, 4505.2, 2327.1),
('0c5d6c5c-f1cb-5e50-8423-4f1da51c6688', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 896, 4507.8, 2328.5),
('f8b6b5f4-295c-5b49-af7d-37ac0e464232', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 897, 4510.5, 2329.8),
('7adceae1-3478-5049-b8d4-a1f1e2dcf1d0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 898, 4513.2, 2331.2),
('ca291bac-f6c4-548d-af6b-ade57cd47519', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 899, 4515.8, 2332.6),
('aa87ccca-1c65-59f0-a5e2-adca88300c7a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 900, 4518.5, 2334.0),
('3c32d8fe-9673-563e-807e-401a16baf72a', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 901, 4521.2, 2335.4),
('b720a891-e0f1-5c46-a176-8093fd6740de', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 902, 4523.8, 2336.8),
('e76b106d-b591-5060-b53c-b0df7e47f7f9', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 903, 4526.5, 2338.1),
('55941ad9-cbb9-51ba-9b68-1ae6dd2f7d6b', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 904, 4529.1, 2339.5),
('4b8ba415-36d6-5d46-8457-57c5d1011aa5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 905, 4531.8, 2340.9),
('4bb2593a-3f49-5b60-9c64-2fc51a5c8d67', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 906, 4534.5, 2342.3),
('6ff7a03c-6d64-5ea5-bd95-377c5384a525', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 907, 4537.1, 2343.7),
('a9d9718d-5858-5a4b-b3bb-f71ed00599d6', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 908, 4539.8, 2345.1),
('4790c412-2a61-5e1f-bb57-2e330e62e7ac', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 909, 4542.4, 2346.4),
('789ed5b9-c6a5-51ef-9115-d67a9eed7a04', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 910, 4545.1, 2347.8),
('0bf804c8-57be-51ce-b980-8297478eab00', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 911, 4547.8, 2349.2),
('0d2fef17-de82-5249-b039-be416cd210df', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 912, 4550.4, 2350.6),
('80e1de2e-d528-5c8f-ba02-26deecff43aa', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 913, 4553.1, 2352.0),
('58b52659-680d-5881-94ff-0bfd09e2f976', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 914, 4555.7, 2353.4),
('05b0b16b-6eba-568f-9645-418957cd71e1', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 915, 4558.4, 2354.8),
('85ab01a3-a7e0-5443-bd24-50556c942ff5', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 916, 4561.1, 2356.1),
('8dce6d9d-a304-51fb-aa8a-a1e4019e7a9e', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 917, 4563.7, 2357.5),
('bae717dd-4db4-513c-866f-1642654de073', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 918, 4566.4, 2358.9),
('8a5c9ccf-3970-5609-b43c-ba9775f7ff20', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 919, 4569.0, 2360.3),
('b7b9c5c3-4f65-5c5e-b1ea-01033f7ff5e0', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 920, 4571.7, 2361.7),
('e869bf33-e4e9-54a0-adf5-63d502a76de8', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 921, 4574.4, 2363.1),
('7ef5a824-9c35-5ae7-90cb-9ea9395cfcae', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 922, 4577.0, 2364.5),
('03d9561a-9407-5bb0-bf0f-c1fb990613b4', (
    SELECT id FROM level_info
    WHERE level_name = 'Kettle Creek'
), 1, 923, 4578.0, 2365.0);
