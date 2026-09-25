import os
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch, AsyncMock
import httpx

os.environ.setdefault('DATABASE_URL', 'sqlite://')
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from src.api.orla_routes import router
from src.api.dependencies import get_current_user
from src.infra.database.mysql_db import get_db
from src.infra.database.models import Base, RoleModel, SecretariaModel, UserModel
from src.infra.database.models.orla_model import OrlaAccess, OrlaInn


class OrlaTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.engine = create_engine('sqlite:///' + self.temp.name + '/test.db', connect_args={'check_same_thread': False})
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        with self.Session() as db:
            roles = {r: RoleModel(slug=r, nome=r) for r in ['cidadao', 'operador_secretaria', 'gestor_secretaria', 'admin']}
            dmtran = SecretariaModel(slug='dmtran', nome='DMTRAN')
            guarda = SecretariaModel(slug='guarda_civil', nome='Guarda Municipal')
            semop = SecretariaModel(slug='semop', nome='SEMOP')
            other = SecretariaModel(slug='other', nome='Other')
            db.add_all([*roles.values(), dmtran, guarda, semop, other]); db.flush()
            specs = [
                ('citizen', 'cidadao', None),
                ('second', 'cidadao', None),
                ('operator', 'operador_secretaria', dmtran),
                ('guard', 'operador_secretaria', guarda),
                ('manager', 'gestor_secretaria', dmtran),
                ('semop_manager', 'gestor_secretaria', semop),
                ('outsider', 'gestor_secretaria', other),
            ]
            self.ids = {}
            for name, role, secretaria in specs:
                user = UserModel(nome=name, senha_hash='test', role=roles[role], secretaria=secretaria)
                db.add(user); db.flush(); self.ids[name] = user.id
            db.commit()
        self.current = self.ids['citizen']
        app = FastAPI(); app.include_router(router)
        def database():
            with self.Session() as db:
                yield db
        def identity():
            with self.Session() as db:
                yield db.get(UserModel, self.current)
        app.dependency_overrides[get_db] = database
        app.dependency_overrides[get_current_user] = identity
        self.client = TestClient(app)

    def tearDown(self):
        self.client.close(); self.engine.dispose(); self.temp.cleanup()

    def register(self, plate='ABC1D23'):
        return self.client.post('/orla/vehicles', json={
            'plate': plate,
            'brand': 'Fiat',
            'model': 'Uno',
            'color': 'Branco',
            'establishment_name': 'Barraca Central',
        })

    def test_default_limit_uniqueness_immutable_and_ownership(self):
        self.assertEqual(self.client.get('/orla/me').json()['vehicle_limit'], 2)
        v = self.register('abc-1d23').json()
        self.assertEqual(v['plate'], 'ABC1D23')
        self.assertEqual(v['brand'], 'Fiat')
        self.assertEqual(v['establishment_name'], 'Barraca Central')
        second = self.register('XYZ1234').json()
        self.assertNotEqual(v['qr_code'], second['qr_code'])
        self.assertEqual(self.register('DEF1234').status_code, 409)
        self.assertEqual(self.client.patch(f"/orla/vehicles/{v['id']}", json={'color': 'Azul'}).status_code, 404)
        self.assertEqual(self.client.delete(f"/orla/vehicles/{v['id']}").status_code, 404)
        self.current = self.ids['second']
        self.assertEqual(self.register().status_code, 409)
        self.assertEqual(self.client.get(f"/orla/vehicles/{v['id']}/accesses").status_code, 404)
        self.assertEqual(self.client.get('/orla/me').json()['vehicles'], [])
        self.assertEqual(self.client.post('/orla/lookup', json={'value': v['qr_code'], 'method': 'qr'}).status_code, 403)

    def test_roles_and_limit(self):
        for who in ['citizen', 'semop_manager', 'outsider']:
            self.current = self.ids[who]
            self.assertEqual(self.client.get('/orla/users').status_code, 403)
        self.current = self.ids['operator']
        self.assertEqual(self.client.get('/orla/users').json(), [])
        self.current = self.ids['citizen']
        self.register()
        self.current = self.ids['operator']
        users = self.client.get('/orla/users').json()
        self.assertEqual(len(users), 1)
        self.assertEqual(users[0]['vehicles'][0]['establishment_name'], 'Barraca Central')
        self.current = self.ids['guard']
        self.assertEqual(self.client.get('/orla/users').status_code, 200)
        url = f"/orla/users/{self.ids['citizen']}/limit"
        self.assertEqual(self.client.put(url, json={'vehicle_limit': 3}).status_code, 403)
        self.assertEqual(self.register().status_code, 403)
        self.current = self.ids['manager']
        self.assertEqual(self.client.put(url, json={'vehicle_limit': -1}).status_code, 422)
        self.assertEqual(self.client.put(url, json={'vehicle_limit': 3}).status_code, 200)
        self.current = self.ids['citizen']
        self.assertEqual(self.client.get('/orla/me').json()['vehicle_limit'], 3)

    def test_public_inn_catalog_does_not_expose_management_data(self):
        with self.Session() as db:
            db.add(OrlaInn(
                name='Pousada Teste', address='Rua protegida, 10', cep='45400-000',
                latitude='-13.28', longitude='-38.96', capacity=20,
                beachfront=True, approval_status='approved',
            ))
            db.commit()
        public = self.client.get('/orla/inns/public')
        self.assertEqual(public.status_code, 200)
        self.assertEqual(set(public.json()[0]), {'id', 'name', 'beachfront'})
        self.current = self.ids['citizen']
        self.assertEqual(self.client.get('/orla/inns?include_pending=true').status_code, 403)
        self.current = self.ids['manager']
        managed = self.client.get('/orla/inns?include_pending=true')
        self.assertEqual(managed.status_code, 200)
        self.assertEqual(managed.json()[0]['address'], 'Rua protegida, 10')

    def test_inn_can_approve_only_its_own_tourist_request(self):
        with self.Session() as db:
            inn = OrlaInn(name='Pousada da Orla', beachfront=True, approval_status='approved')
            other_inn = OrlaInn(name='Outra Pousada', beachfront=True, approval_status='approved')
            db.add_all([inn, other_inn]); db.flush()
            citizen_role = db.query(RoleModel).filter_by(slug='cidadao').first()
            inn_user = UserModel(
                nome='Pousada', senha_hash='test', role=citizen_role,
                business_category='pousada_hotel', managed_inn_id=inn.id,
            )
            guest = UserModel(
                nome='Turista', senha_hash='test', role=citizen_role,
                tipo_usuario='turista', tipo_estadia='pousada', pousada_id=inn.id,
                estadia_inicio='2026-09-20', estadia_fim='2026-09-30',
                orla_access_requested=True, orla_access_status='solicitado',
            )
            other_guest = UserModel(
                nome='Outro Turista', senha_hash='test', role=citizen_role,
                tipo_usuario='turista', tipo_estadia='pousada', pousada_id=other_inn.id,
                orla_access_requested=True, orla_access_status='solicitado',
            )
            db.add_all([inn_user, guest, other_guest]); db.flush()
            self.ids['inn_user'] = inn_user.id
            self.ids['guest'] = guest.id
            self.ids['other_guest'] = other_guest.id
            db.commit()
        self.current = self.ids['inn_user']
        requests = self.client.get('/orla/stay-requests')
        self.assertEqual(requests.status_code, 200)
        self.assertEqual([item['id'] for item in requests.json()], [self.ids['guest']])
        approved = self.client.put(
            f"/orla/stay-requests/{self.ids['guest']}/approval", json={'approved': True},
        )
        self.assertEqual(approved.status_code, 200)
        self.assertEqual(approved.json()['status'], 'aprovado')
        self.current = self.ids['guest']
        notifications = self.client.get('/orla/notifications')
        self.assertEqual(notifications.status_code, 200)
        self.assertEqual(notifications.json()[0]['kind'], 'acesso_aprovado')
        notification_id = notifications.json()[0]['id']
        self.assertFalse(notifications.json()[0]['is_read'])
        self.assertTrue(
            self.client.put(f'/orla/notifications/{notification_id}/read').json()['is_read'],
        )
        self.current = self.ids['inn_user']
        self.assertEqual(
            self.client.put(
                f"/orla/stay-requests/{self.ids['other_guest']}/approval", json={'approved': True},
            ).status_code,
            404,
        )

    def test_movements_and_revocation(self):
        v = self.register().json()
        self.current = self.ids['operator']
        body = {'value': v['qr_code'], 'method': 'qr', 'action': 'entry'}
        self.assertEqual(self.client.post('/orla/accesses', json=body).status_code, 201)
        self.assertEqual(self.client.post('/orla/accesses', json=body).status_code, 201)
        self.current = self.ids['manager']
        self.client.put(f"/orla/users/{self.ids['citizen']}/limit", json={'vehicle_limit': 0})
        self.current = self.ids['operator']
        self.assertEqual(self.client.post('/orla/accesses', json={**body, 'action': 'exit', 'method': 'plate', 'value': 'ABC1D23'}).status_code, 422)
        self.assertEqual(self.client.post('/orla/accesses', json=body).status_code, 403)
        self.current = self.ids['citizen']
        history = self.client.get(f"/orla/vehicles/{v['id']}/accesses").json()
        self.assertEqual([h['action'] for h in history], ['entry', 'entry'])
        with self.Session() as db:
            self.assertEqual(db.query(OrlaAccess).count(), 2)

    def test_concurrent_limit_and_scan(self):
        with ThreadPoolExecutor(max_workers=4) as pool:
            responses = list(pool.map(self.register, ['AAA1234', 'BBB1234', 'CCC1234', 'DDD1234']))
        self.assertEqual(sorted(r.status_code for r in responses), [201, 201, 409, 409])
        v = next(r.json() for r in responses if r.status_code == 201)
        self.current = self.ids['operator']
        with ThreadPoolExecutor(max_workers=4) as pool:
            responses = list(pool.map(lambda _: self.client.post('/orla/accesses', json={'value': v['qr_code'], 'method': 'qr', 'action': 'entry'}), range(4)))
        self.assertEqual(sorted(r.status_code for r in responses), [201, 201, 201, 201])

    def test_validation_and_ocr_configuration(self):
        self.assertEqual(self.register('invalid').status_code, 422)
        self.current = self.ids['operator']
        self.assertEqual(self.client.post('/orla/lookup', json={'method': 'qr', 'value': 'tampered'}).status_code, 422)
        self.assertEqual(self.client.post('/orla/lookup', json={'method': 'plate', 'value': 'ZZZ9999'}).status_code, 404)
        with patch.dict(os.environ, {'PLATE_RECOGNIZER_TOKEN': ''}):
            self.assertEqual(self.client.post('/orla/recognize-plate', files={'file': ('photo.jpg', b'image', 'image/jpeg')}).status_code, 503)
        with patch.dict(os.environ, {'VEHICLE_RESTRICTION_API_URL': ''}):
            result = self.client.post('/orla/plate-security', json={'method': 'plate', 'value': 'ABC1D23'})
            self.assertEqual(result.status_code, 200)
            self.assertFalse(result.json()['configured'])


    def test_ocr_candidates_and_failure(self):
        self.current = self.ids['operator']
        response = httpx.Response(200, json={'results': [{'plate': 'abc1d23', 'score': .98}, {'plate': 'garbage'}]}, request=httpx.Request('POST', 'https://example.test'))
        with patch.dict(os.environ, {'PLATE_RECOGNIZER_TOKEN': 'test'}), patch('src.api.orla_routes.httpx.AsyncClient') as factory:
            client = AsyncMock()
            factory.return_value.__aenter__.return_value = client
            client.post.return_value = response
            result = self.client.post('/orla/recognize-plate', files={'file': ('photo.jpg', b'image', 'image/jpeg')})
            self.assertEqual(result.json()['candidates'], [{'plate': 'ABC1D23', 'score': .98}])
            self.assertEqual(self.client.post('/orla/recognize-plate', files={'file': ('bad.txt', b'bad', 'text/plain')}).status_code, 422)
            self.assertEqual(self.client.post('/orla/recognize-plate', files={'file': ('big.jpg', b'x' * (5 * 1024 * 1024 + 1), 'image/jpeg')}).status_code, 413)
            client.post.side_effect = httpx.ReadTimeout('timeout')
            self.assertEqual(self.client.post('/orla/recognize-plate', files={'file': ('photo.jpg', b'image', 'image/jpeg')}).status_code, 502)

    def test_plate_security_external_integration(self):
        self.current = self.ids['operator']
        response = httpx.Response(200, json={'roubo_furto': True, 'mensagem': 'Veículo com restrição'}, request=httpx.Request('GET', 'https://example.test'))
        with patch.dict(os.environ, {'VEHICLE_RESTRICTION_API_URL': 'https://example.test/{plate}', 'VEHICLE_RESTRICTION_API_TOKEN': 'token'}), patch('src.api.orla_routes.httpx.AsyncClient') as factory:
            client = AsyncMock()
            factory.return_value.__aenter__.return_value = client
            client.get.return_value = response
            result = self.client.post('/orla/plate-security', json={'method': 'plate', 'value': 'abc-1d23'})
            self.assertEqual(result.status_code, 200)
            self.assertTrue(result.json()['stolen'])
            client.get.assert_called_once()


if __name__ == '__main__':
    unittest.main()
